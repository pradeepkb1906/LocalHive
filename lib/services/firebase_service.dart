import 'dart:math';

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
        options: FirebaseOptions(
          apiKey: kIsWeb ? FirebaseConfig.apiKey : FirebaseConfig.androidApiKey,
          authDomain: FirebaseConfig.authDomain,
          projectId: FirebaseConfig.projectId,
          storageBucket: FirebaseConfig.storageBucket,
          messagingSenderId: FirebaseConfig.messagingSenderId,
          appId: kIsWeb ? FirebaseConfig.appId : FirebaseConfig.androidAppId,
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
    // 4-digit OTP the customer shares with the delivery partner on arrival.
    final otp = b.fulfillment == 'delivery'
        ? (1000 + Random().nextInt(9000)).toString()
        : '';
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
      'fulfillment': b.fulfillment,
      'pickupEta': b.pickupEta,
      'otp': otp,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final isOrder = b.category != 'home_service';
    await _queueNotifications(
      event: isOrder ? 'order_placed' : 'booking_requested',
      bookingId: doc.id,
      customerMsg: isOrder
          ? 'LocalHive: your order at ${b.providerName} (${b.detail}) is placed. '
              '${otp.isNotEmpty ? 'Your delivery OTP is $otp — share it ONLY when your order arrives. ' : ''}'
              'We will notify you as it is prepared.'
          : 'LocalHive: your request to ${b.providerName} (${b.detail}) was sent. '
              'We will notify you when it is accepted.',
      providerMsg: isOrder
          ? 'LocalHive: NEW ORDER — ${b.detail}'
              '${b.fulfillment == 'delivery' ? ' (deliver to ${b.address})' : ' (pickup${b.pickupEta.isNotEmpty ? ', customer arriving ${b.pickupEta}' : ''})'}. '
              'Open your Provider Dashboard.'
          : 'LocalHive: NEW JOB REQUEST — ${b.detail} at ${b.address}. '
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
      'Preparing' => (
          'LocalHive: ${b.providerName} accepted your order and is preparing it now.',
          null
        ),
      'Ready' => (
          b.fulfillment == 'delivery'
              ? 'LocalHive: your order at ${b.providerName} is ready — a delivery '
                  'partner will pick it up shortly.'
              : 'LocalHive: your order at ${b.providerName} is READY FOR PICKUP!',
          null
        ),
      'Out for delivery' => (
          'LocalHive: your order from ${b.providerName} is OUT FOR DELIVERY to ${b.address}.',
          null
        ),
      'Delivered' => (
          'LocalHive: your order from ${b.providerName} was delivered. Enjoy!',
          'LocalHive: order ${b.detail} was delivered to the customer.'
        ),
      'Completed' => (
          'LocalHive: your ${b.category == 'home_service' ? 'job' : 'order'} with '
              '${b.providerName} is complete. Total \$${b.amount.toStringAsFixed(2)}. Thank you!',
          'LocalHive: marked complete. Payout of '
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

  /// Count of orders needing the owner's attention (new or in progress).
  Stream<int> pendingOwnerJobsCount() {
    const active = {'Placed', 'Requested', 'Preparing', 'Ready'};
    return providerJobsStream()
        .map((jobs) => jobs.where((j) => active.contains(j.status)).length);
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
      fulfillment: (m['fulfillment'] ?? '') as String,
      pickupEta: (m['pickupEta'] ?? '') as String,
      otp: (m['otp'] ?? '') as String,
    );
  }

  // ---- User account type (customer | provider | delivery) ----

  Future<String> getRole() async {
    if (!ready || currentUser == null) return 'customer';
    try {
      final doc = await _db!.collection('users').doc(_uid).get();
      return (doc.data()?['role'] ?? 'customer') as String;
    } catch (_) {
      return 'customer';
    }
  }

  Future<void> setRole(String role) async {
    if (!ready || currentUser == null) return;
    await _db!.collection('users').doc(_uid).set(
        {'role': role, 'email': currentUser?.email ?? ''},
        SetOptions(merge: true));
  }

  // ---- Truck arrival alerts ----

  /// Follow a truck to be notified when it announces arrival.
  Future<void> followTruck(Provider truck,
      {required String phone, required String email}) async {
    if (!ready || currentUser == null) return;
    String ownerId = '';
    try {
      final doc = await _db!.collection('providers').doc(truck.id).get();
      ownerId = (doc.data()?['ownerId'] ?? '') as String;
    } catch (_) {}
    await _db!.collection('truck_followers').doc('${truck.id}_$_uid').set({
      'truckId': truck.id,
      'truckName': truck.name,
      'truckOwnerId': ownerId,
      'userId': _uid,
      'phone': phone,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unfollowTruck(String truckId) async {
    if (!ready || currentUser == null) return;
    await _db!
        .collection('truck_followers')
        .doc('${truckId}_$_uid')
        .delete();
  }

  Future<bool> isFollowingTruck(String truckId) async {
    if (!ready || currentUser == null) return false;
    try {
      final doc = await _db!
          .collection('truck_followers')
          .doc('${truckId}_$_uid')
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Owner announces the truck has arrived: updates the listing location and
  /// queues an alert to every follower. Returns the follower count notified.
  Future<int> announceArrival(Provider truck, String locationText) async {
    if (!ready || currentUser == null) return 0;
    await _db!
        .collection('providers')
        .doc(truck.id)
        .update({'city': locationText});
    final followers = await _db!
        .collection('truck_followers')
        .where('truckOwnerId', isEqualTo: _uid)
        .where('truckId', isEqualTo: truck.id)
        .get();
    final batch = _db!.batch();
    for (final f in followers.docs) {
      final m = f.data();
      batch.set(_db!.collection('notifications').doc(), {
        'recipient': 'follower',
        'phone': (m['phone'] ?? '') as String,
        'email': (m['email'] ?? '') as String,
        'channels': ['sms', 'email'],
        'event': 'truck_arrived',
        'message': 'LocalHive: ${truck.name} has ARRIVED at $locationText — '
            'come grab your favorites or pre-order in the app to skip the line!',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return followers.docs.length;
  }

  /// Follower count per truck the signed-in owner runs — their opted-in
  /// customer base.
  Future<Map<String, int>> myTruckFollowerCounts() async {
    if (!ready || currentUser == null) return {};
    final snap = await _db!
        .collection('truck_followers')
        .where('truckOwnerId', isEqualTo: _uid)
        .get();
    final counts = <String, int>{};
    for (final d in snap.docs) {
      final name = (d.data()['truckName'] ?? '') as String;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts;
  }

  Future<List<Provider>> myListings({String? category}) async {
    if (!ready || currentUser == null) return [];
    var q = _db!.collection('providers').where('ownerId', isEqualTo: _uid);
    if (category != null) q = q.where('category', isEqualTo: category);
    final snap = await q.get();
    return snap.docs.map((d) {
      final m = d.data();
      return Provider(
        id: d.id,
        name: (m['name'] ?? '') as String,
        category: (m['category'] ?? '') as String,
        subtitle: (m['subtitle'] ?? '') as String,
        rating: ((m['rating'] ?? 0) as num).toDouble(),
        reviews: ((m['reviews'] ?? 0) as num).toInt(),
        city: (m['city'] ?? '') as String,
        emoji: '',
      );
    }).toList();
  }

  // ---- Delivery job board ----

  /// Store owner sends a Ready delivery order to the job board.
  Future<void> createDeliveryJob(Booking b, {double fee = 4.99}) async {
    if (!ready || b.id.isEmpty) return;
    await _db!.collection('delivery_jobs').doc(b.id).set({
      'storeName': b.providerName,
      'orderDetail': b.detail,
      'dropAddress': b.address,
      'customerPhone': b.customerPhone, // delivery partner needs to reach them
      'customerEmail': b.customerEmail,
      'otp': b.otp, // partner must collect this from the customer to complete
      'fee': fee,
      'status': 'Open',
      'deliveryPersonId': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> deliveryJobsStream() {
    if (!ready || currentUser == null) return Stream.value(const []);
    return _db!.collection('delivery_jobs').snapshots().map((snap) => snap.docs
        .map((d) => {...d.data(), 'id': d.id})
        .where((j) =>
            j['status'] != 'Delivered' &&
            (j['deliveryPersonId'] == '' || j['deliveryPersonId'] == _uid))
        .toList());
  }

  Future<void> claimDeliveryJob(String jobId) async {
    await _db!.collection('delivery_jobs').doc(jobId).update({
      'deliveryPersonId': _uid,
      'status': 'Claimed',
    });
  }

  /// Advance a claimed delivery: 'PickedUp' → booking 'Out for delivery';
  /// 'Delivered' → booking 'Delivered'. Queues customer notifications.
  Future<void> advanceDeliveryJob(
      String jobId, String jobStatus, Booking? bookingForNotify) async {
    await _db!
        .collection('delivery_jobs')
        .doc(jobId)
        .update({'status': jobStatus});
    final bookingStatus =
        jobStatus == 'PickedUp' ? 'Out for delivery' : 'Delivered';
    await _db!
        .collection('bookings')
        .doc(jobId)
        .update({'status': bookingStatus});
    if (bookingForNotify != null) {
      await _queueNotifications(
        event: 'delivery_${jobStatus.toLowerCase()}',
        bookingId: jobId,
        customerMsg: bookingStatus == 'Out for delivery'
            ? 'LocalHive: your order from ${bookingForNotify.providerName} is '
                'OUT FOR DELIVERY to ${bookingForNotify.address}.'
            : 'LocalHive: your order from ${bookingForNotify.providerName} was '
                'delivered. Enjoy!',
        providerMsg: bookingStatus == 'Delivered'
            ? 'LocalHive: order delivered to the customer.'
            : null,
        booking: bookingForNotify,
      );
    }
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
    String availableFrom = '',
    String availableTo = '',
  }) async {
    if (!ready) return;
    await _db!.collection('provider_applications').add({
      'userId': _uid,
      'type': type,
      'businessName': businessName,
      'city': city,
      'availableFrom': availableFrom,
      'availableTo': availableTo,
      'status': 'in_review',
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Draft listing, hidden until approved: flipping `live` to true in the
    // console (or a future admin screen) publishes it into the catalog.
    await _db!.collection('providers').add({
      'name': businessName,
      'category': type,
      'subtitle': type == 'delivery'
          ? 'Delivery partner'
          : 'New on LocalHive',
      'rating': 5.0,
      'reviews': 0,
      'hourlyRate': type == 'home_service' ? 30.0 : 0.0,
      'city': city,
      'availableFrom': availableFrom,
      'availableTo': availableTo,
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
          availableFrom: (m['availableFrom'] ?? '') as String,
          availableTo: (m['availableTo'] ?? '') as String,
        );
      }).toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));
      return list;
    });
  }
}
