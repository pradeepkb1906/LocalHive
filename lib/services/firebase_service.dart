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

  Future<void> addBooking(Booking b) async {
    if (!ready) return;
    await _db!.collection('bookings').add({
      'userId': _uid,
      'providerName': b.providerName,
      'detail': b.detail,
      'status': b.status,
      'amount': b.amount,
      'createdAt': FieldValue.serverTimestamp(),
    });
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
      return docs.map((d) {
        final m = d.data();
        return Booking(
          (m['providerName'] ?? '') as String,
          (m['detail'] ?? '') as String,
          (m['status'] ?? '') as String,
          ((m['amount'] ?? 0) as num).toDouble(),
        );
      }).toList();
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
        );
      }).toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));
      return list;
    });
  }
}
