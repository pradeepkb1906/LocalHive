import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_config.dart';
import '../models/data.dart';

/// Thin wrapper around Firebase. The app degrades gracefully: if
/// initialization fails (offline, missing config), everything falls back to
/// local in-memory state and the UI keeps working.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool ready = false;
  FirebaseAuth? _auth;
  FirebaseFirestore? _db;

  Future<void> init() async {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: FirebaseConfig.apiKey,
          authDomain: FirebaseConfig.authDomain,
          projectId: FirebaseConfig.projectId,
          storageBucket: FirebaseConfig.storageBucket,
          messagingSenderId: FirebaseConfig.messagingSenderId,
          appId: FirebaseConfig.appId,
        ),
      );
      _auth = FirebaseAuth.instance;
      _db = FirebaseFirestore.instance;
      ready = true;
    } catch (e) {
      debugPrint('Firebase init failed, running in offline mode: $e');
      ready = false;
    }
  }

  User? get currentUser => _auth?.currentUser;

  /// Web phone sign-in step 1: sends the SMS. The plugin renders an
  /// invisible reCAPTCHA automatically on web.
  Future<ConfirmationResult> sendSmsCode(String phoneNumber) {
    return _auth!.signInWithPhoneNumber(phoneNumber);
  }

  Future<UserCredential> confirmSmsCode(ConfirmationResult result, String code) {
    return result.confirm(code);
  }

  Future<void> setDisplayName(String name) async {
    await _auth?.currentUser?.updateDisplayName(name);
  }

  Future<void> signOut() async => _auth?.signOut();

  // ---- Firestore ----

  String get _uid => currentUser?.uid ?? 'guest';

  // ---- Auth: email + password ----

  Future<String?> signUpWithEmail(String email, String password, String name) async {
    try {
      final cred = await _auth!
          .createUserWithEmailAndPassword(email: email, password: password);
      await cred.user?.updateDisplayName(name);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign-up failed.';
    }
  }

  Future<String?> signInWithEmail(String email, String password) async {
    try {
      await _auth!.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign-in failed.';
    }
  }

  Future<void> addBooking(Booking b) async {
    if (!ready) return;
    // Denormalize the listing owner so provider-side queries are cheap and
    // provable under security rules.
    String providerOwnerId = '';
    if (b.providerId.isNotEmpty) {
      try {
        final prov =
            await _db!.collection('providers').doc(b.providerId).get();
        providerOwnerId = (prov.data()?['ownerId'] ?? '') as String;
      } catch (_) {}
    }
    final doc = await _db!.collection('bookings').add({
      'userId': _uid,
      'providerOwnerId': providerOwnerId,
      'providerId': b.providerId,
      'providerName': b.providerName,
      'category': b.category,
      'detail': b.detail,
      'status': b.status,
      'amount': b.amount,
      'address': b.address,
      'customerName': b.customerName,
      'customerPhone': b.customerPhone,
      'customerEmail': b.customerEmail,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _queueNotifications(
      event: 'booking_requested',
      bookingId: doc.id,
      customerMsg:
          'LocalHive: your request to ${b.providerName} (${b.detail}) was sent. '
          'We will notify you when it is accepted.',
      providerMsg:
          'LocalHive: NEW JOB REQUEST — ${b.detail} at ${b.address}. '
          'Open your Provider Dashboard to accept.',
      booking: b,
    );
  }

  /// Moves a booking through its lifecycle and queues the matching
  /// customer/provider notifications.
  Future<void> updateBookingStatus(Booking b, String newStatus) async {
    if (!ready || b.id.isEmpty) return;
    await _db!.collection('bookings').doc(b.id).update({'status': newStatus});
    final msgs = switch (newStatus) {
      'Accepted' => (
          'LocalHive: ${b.providerName} ACCEPTED your booking (${b.detail}). '
              'They will arrive at ${b.address}.',
          'LocalHive: you accepted ${b.detail}. Customer: ${b.customerName} '
              '${b.customerPhone}.'
        ),
      'Declined' => (
          'LocalHive: ${b.providerName} cannot take your booking (${b.detail}). '
              'Please pick another provider.',
          null
        ),
      'Completed' => (
          'LocalHive: your job with ${b.providerName} is complete. '
              'Total \$${b.amount.toStringAsFixed(2)}. Thank you!',
          'LocalHive: job marked complete. Payout of '
              '\$${(b.amount / (1 + platformFeePct)).toStringAsFixed(2)} is on the way.'
        ),
      _ => (null, null),
    };
    await _queueNotifications(
      event: 'booking_${newStatus.toLowerCase()}',
      bookingId: b.id,
      customerMsg: msgs.$1,
      providerMsg: msgs.$2,
      booking: b,
    );
  }

  /// Notification outbox: one Firestore doc per message. A dispatcher
  /// (Twilio for SMS, Brevo/Resend for email) drains docs with
  /// status == 'pending' once those accounts exist — no app changes needed.
  Future<void> _queueNotifications({
    required String event,
    required String bookingId,
    String? customerMsg,
    String? providerMsg,
    required Booking booking,
  }) async {
    final batch = _db!.batch();
    if (customerMsg != null) {
      batch.set(_db!.collection('notifications').doc(), {
        'recipient': 'customer',
        'phone': booking.customerPhone,
        'email': booking.customerEmail,
        'channels': ['sms', 'email'],
        'event': event,
        'bookingId': bookingId,
        'message': customerMsg,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (providerMsg != null) {
      // Deliver to the contact details on the provider's listing.
      String provPhone = '', provEmail = '';
      if (booking.providerId.isNotEmpty) {
        try {
          final doc = await _db!
              .collection('providers')
              .doc(booking.providerId)
              .get();
          final m = doc.data() ?? {};
          provPhone = (m['phone'] ?? '') as String;
          provEmail = (m['email'] ?? '') as String;
        } catch (_) {}
      }
      batch.set(_db!.collection('notifications').doc(), {
        'recipient': 'provider',
        'providerId': booking.providerId,
        'phone': provPhone,
        'email': provEmail,
        'channels': ['sms', 'email'],
        'event': event,
        'bookingId': bookingId,
        'message': providerMsg,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Incoming jobs/orders for listings owned by the signed-in provider.
  Stream<List<Booking>> providerJobsStream() {
    if (!ready || currentUser == null) return Stream.value(const []);
    return _db!
        .collection('bookings')
        .where('providerOwnerId', isEqualTo: _uid)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.toList()
        ..sort((a, b) {
          final ta = a.data()['createdAt'];
          final tb = b.data()['createdAt'];
          if (ta is! Timestamp) return -1;
          if (tb is! Timestamp) return 1;
          return tb.compareTo(ta);
        });
      return docs.map(_bookingFromDoc).toList();
    });
  }

  Booking _bookingFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Booking(
      (m['providerName'] ?? '') as String,
      (m['detail'] ?? '') as String,
      (m['status'] ?? '') as String,
      ((m['amount'] ?? 0) as num).toDouble(),
      id: d.id,
      providerId: (m['providerId'] ?? '') as String,
      category: (m['category'] ?? '') as String,
      address: (m['address'] ?? '') as String,
      customerName: (m['customerName'] ?? '') as String,
      customerPhone: (m['customerPhone'] ?? '') as String,
      customerEmail: (m['customerEmail'] ?? '') as String,
    );
  }

  Stream<List<Booking>> bookingsStream() {
    if (!ready) return const Stream.empty();
    return _db!
        .collection('bookings')
        .where('userId', isEqualTo: _uid)
        .snapshots()
        .map((snap) {
      final docs = snap.docs.toList()
        ..sort((a, b) {
          final ta = a.data()['createdAt'];
          final tb = b.data()['createdAt'];
          if (ta is! Timestamp) return -1;
          if (tb is! Timestamp) return 1;
          return tb.compareTo(ta);
        });
      return docs.map(_bookingFromDoc).toList();
    });
  }

  Future<void> submitProviderApplication({
    required String type,
    required String businessName,
    required String city,
  }) async {
    if (!ready) return;
    await _db!.collection('provider_applications').add({
      'userId': _uid,
      'type': type,
      'businessName': businessName,
      'city': city,
      'status': 'in_review',
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Draft listing, hidden until approved: flipping `live` to true in the
    // console (or a future admin screen) publishes it into the catalog.
    await _db!.collection('providers').add({
      'name': businessName,
      'category': type,
      'subtitle': 'New on LocalHive',
      'rating': 5.0,
      'reviews': 0,
      'hourlyRate': type == 'home_service' ? 30.0 : 0.0,
      'city': city,
      'verified': false,
      'live': false,
      'ownerId': _uid,
      'phone': currentUser?.phoneNumber ?? '',
      'email': currentUser?.email ?? '',
    });
  }

  /// Live catalog for one category. Only `live: true` listings are shown.
  /// Equality-only filters use Firestore index merging — no composite index.
  Stream<List<Provider>> providersStream(String category) {
    if (!ready) return const Stream.empty();
    return _db!
        .collection('providers')
        .where('category', isEqualTo: category)
        .where('live', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) {
        final m = d.data();
        return Provider(
          id: d.id,
          name: (m['name'] ?? '') as String,
          category: category,
          subtitle: (m['subtitle'] ?? '') as String,
          rating: ((m['rating'] ?? 0) as num).toDouble(),
          reviews: ((m['reviews'] ?? 0) as num).toInt(),
          hourlyRate: ((m['hourlyRate'] ?? 0) as num).toDouble(),
          city: (m['city'] ?? '') as String,
          verified: (m['verified'] ?? false) as bool,
          emoji: '',
          lat: ((m['lat'] ?? 0) as num).toDouble(),
          lng: ((m['lng'] ?? 0) as num).toDouble(),
        );
      }).toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));
      return list;
    });
  }
}
