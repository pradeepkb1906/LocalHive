import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_config.dart';
import '../models/data.dart';
import 'courier_beacon.dart';

/// Thin wrapper around Firebase. The app degrades gracefully: if
/// initialization fails (offline, missing config), everything falls back to
/// local in-memory state and the UI keeps working.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool ready = false;
  FirebaseAuth? _auth;
  FirebaseFirestore? _db;

  /// Firestore listeners are expensive: creating one per widget build causes
  /// a rebuild storm that freezes the UI. Streams are created once per
  /// (query, user) and shared.
  final Map<String, Stream> _streams = {};

  /// The most recent value each shared stream produced.
  ///
  /// A broadcast stream does not replay to a subscriber that arrives late, and
  /// Firestore only pushes again when the data changes. So the second widget to
  /// listen used to wait forever: the owner's home screen subscribed first for
  /// the "orders waiting" badge, and when they then opened the Provider
  /// Dashboard it sat on a spinner with the orders already in hand. Keeping the
  /// last value and handing it straight to new subscribers fixes that without
  /// opening a second listener per widget.
  final Map<String, Object?> _latest = {};

  Stream<T> _shared<T>(String key, Stream<T> Function() create) {
    final k = '$key|$_uid';
    final source = _streams.putIfAbsent(
      k,
      () => create().map((value) {
        _latest[k] = value;
        return value;
      }).asBroadcastStream(),
    ) as Stream<T>;

    return Stream<T>.multi((controller) {
      if (_latest.containsKey(k)) controller.add(_latest[k] as T);
      final sub = source.listen(controller.add,
          onError: controller.addError, onDone: controller.close);
      controller.onCancel = sub.cancel;
    });
  }

  void _resetStreams() {
    _streams.clear();
    _latest.clear();
  }

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

  Future<UserCredential> confirmSmsCode(
      ConfirmationResult result, String code) {
    return result.confirm(code);
  }

  Future<void> setDisplayName(String name) async {
    await _auth?.currentUser?.updateDisplayName(name);
  }

  /// Sends the Firebase password-reset email. Returns error text or null.
  Future<String?> sendPasswordReset(String email) async {
    if (!ready) return 'Offline — try again when connected.';
    try {
      await _auth!.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      // Don't leak whether an account exists.
      if (e.code == 'user-not-found') return null;
      return e.message ?? 'Could not send the reset email.';
    }
  }

  Future<void> signOut() async {
    _resetStreams();
    CourierBeacon.instance.reset(); // stop sharing location on sign-out
    await _auth?.signOut();
  }

  // ---- Firestore ----

  String get _uid => currentUser?.uid ?? 'guest';

  // ---- Auth: email + password ----

  Future<String?> signUpWithEmail(
      String email, String password, String name) async {
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

  /// Writes a booking and returns its new document id, or null if it could not
  /// be written. Olivia needs the id back so she can confirm and then track the
  /// order she just placed.
  Future<String?> addBooking(Booking b) async {
    if (!ready) return null;
    // 4-digit OTP the customer shares with the delivery partner on arrival.
    final otp = b.fulfillment == 'delivery'
        ? (1000 + Random().nextInt(9000)).toString()
        : '';
    // Denormalize the listing owner so provider-side queries are cheap and
    // provable under security rules.
    String providerOwnerId = '';
    if (b.providerId.isNotEmpty) {
      try {
        final prov = await _db!.collection('providers').doc(b.providerId).get();
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
      // Rounded here too, not just at the call sites: this is the figure a
      // customer is asked to hand over, and it must be whole cents whoever
      // built the booking.
      'amount': money(b.amount),
      'address': b.address,
      'customerName': b.customerName,
      'customerPhone': b.customerPhone,
      'customerEmail': b.customerEmail,
      'fulfillment': b.fulfillment,
      'pickupEta': b.pickupEta,
      'otp': otp,
      // The order contents. The business needs this to pack the order, the
      // customer to check it, and the courier to know what they are carrying —
      // so it lives on the booking rather than being reconstructed from a
      // catalog that may have changed since.
      'items': b.items.map((l) => l.toMap()).toList(),
      // LocalHive never takes payment in-app: the customer settles directly
      // with the business on arrival.
      'paymentMode': 'manual',
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
    return doc.id;
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
      'Cancelled' => (
          'LocalHive: your booking with ${b.providerName} (${b.detail}) has '
              'been cancelled. Nothing is owed.',
          'LocalHive: the customer cancelled ${b.detail} before you accepted. '
              'No action needed.'
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
          final doc =
              await _db!.collection('providers').doc(booking.providerId).get();
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
  Stream<int> pendingOwnerJobsCount() => _shared('ownerCount', () {
        const active = {'Placed', 'Requested', 'Preparing', 'Ready'};
        return providerJobsStream()
            .map((jobs) => jobs.where((j) => active.contains(j.status)).length);
      });

  /// Incoming jobs/orders for listings owned by the signed-in provider.
  Stream<List<Booking>> providerJobsStream() {
    if (!ready || currentUser == null) return Stream.value(const []);
    return _shared(
        'providerJobs',
        () => _db!
                .collection('bookings')
                .where('providerOwnerId', isEqualTo: _uid)
                .snapshots()
                .map((snap) {
              final docs = snap.docs.toList()
                ..sort((a, b) {
                  final ta = a.data()['createdAt'];
                  final tb = b.data()['createdAt'];
                  // Rows still waiting on serverTimestamp (or legacy rows
                  // without one) sink to the bottom of a newest-first list.
                  if (ta is! Timestamp) return 1;
                  if (tb is! Timestamp) return -1;
                  return tb.compareTo(ta);
                });
              return docs.map(_bookingFromDoc).toList();
            }));
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
      // Orders placed before items were recorded have no list. Those fall back
      // to the summary line, so an older order still reads sensibly.
      items: ((m['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => OrderLine.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
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

  // ---- Feature flags (admin-controlled role access) ----

  /// The admin's role/feature toggle overrides. Empty map when nothing has
  /// been toggled yet — the defaults in feature_flags.dart then apply, so a
  /// fresh install behaves exactly as before the console existed.
  Stream<Map<String, dynamic>> featureFlagsStream() {
    if (!ready) return Stream.value(const {});
    return _shared(
        'featureFlags',
        () => _db!
            .collection('config')
            .doc('feature_flags')
            .snapshots()
            .map((doc) => doc.data() ?? const {}));
  }

  /// Flips one (role, feature) toggle. Merge-write so each flip touches only
  /// its own key; security rules restrict this to admins.
  Future<void> setFeatureFlag(String role, String feature, bool enabled) async {
    if (!ready) return;
    await _db!.collection('config').doc('feature_flags').set({
      role: {feature: enabled}
    }, SetOptions(merge: true));
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
    await _db!.collection('truck_followers').doc('${truckId}_$_uid').delete();
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
  ///
  /// The job board is readable by every signed-in partner so open jobs can be
  /// browsed, so it deliberately carries NO customer contact details and NOT
  /// the delivery OTP. Those live on the booking, which only the customer, the
  /// business owner and the *assigned* partner can read.
  Future<void> createDeliveryJob(Booking b, {double fee = 4.99}) async {
    if (!ready || b.id.isEmpty) return;
    await _db!.collection('delivery_jobs').doc(b.id).set({
      'storeName': b.providerName,
      'orderDetail': b.detail,
      // Copied onto the job so a partner can check the handover against the
      // order without being able to read the booking. What goods are in the bag
      // is not private; the customer's phone, email and OTP stay on the booking
      // and are readable only once this partner is assigned.
      'items': b.items.map((l) => l.toMap()).toList(),
      'dropAddress': b.address,
      'fee': fee,
      'status': 'Open',
      'deliveryPersonId': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// The private half of a delivery job: customer phone/email and the OTP.
  /// Readable only once this partner is assigned (enforced by rules).
  Future<Map<String, dynamic>?> deliveryJobPrivate(String jobId) async {
    if (!ready) return null;
    try {
      final doc = await _db!.collection('bookings').doc(jobId).get();
      if (!doc.exists) return null;
      final d = doc.data()!;
      return {
        'otp': (d['otp'] ?? '') as String,
        'customerPhone': (d['customerPhone'] ?? '') as String,
        'customerEmail': (d['customerEmail'] ?? '') as String,
      };
    } catch (e) {
      debugPrint('deliveryJobPrivate failed: $e');
      return null;
    }
  }

  // ---- Live courier tracking ----

  /// The assigned partner's device publishes its GPS position here while a
  /// delivery is in progress. The customer's tracking map reads it live.
  Future<void> publishCourierPosition(String jobId, double lat, double lng,
      {double speedMps = 0}) async {
    if (!ready) return;
    try {
      await _db!.collection('delivery_jobs').doc(jobId).update({
        'courierLat': lat,
        'courierLng': lng,
        'courierSpeedMps': speedMps,
        'courierAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // A dropped position update is not worth interrupting a delivery for.
      debugPrint('publishCourierPosition failed: $e');
    }
  }

  /// Live view of a single delivery job — the customer's tracking map.
  Stream<Map<String, dynamic>?> deliveryJobStream(String jobId) {
    if (!ready) return Stream.value(null);
    return _shared(
        'deliveryJob:$jobId',
        () => _db!
            .collection('delivery_jobs')
            .doc(jobId)
            .snapshots()
            .map((d) => d.exists ? {...d.data()!, 'id': d.id} : null));
  }

  Stream<List<Map<String, dynamic>>> deliveryJobsStream() {
    if (!ready || currentUser == null) return Stream.value(const []);
    return _shared(
        'deliveryJobs',
        () => _db!.collection('delivery_jobs').snapshots().map((snap) {
              final jobs = snap.docs
                  .map((d) => {...d.data(), 'id': d.id})
                  .where((j) =>
                      j['status'] != 'Delivered' &&
                      (j['deliveryPersonId'] == '' ||
                          j['deliveryPersonId'] == _uid))
                  .toList()
                // Newest job first, like every board a courier has used.
                ..sort((a, b) {
                  final ta = a['createdAt'];
                  final tb = b['createdAt'];
                  if (ta is! Timestamp) return 1;
                  if (tb is! Timestamp) return -1;
                  return tb.compareTo(ta);
                });
              return jobs;
            }));
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
    return _shared(
        'bookings',
        () => _db!
                .collection('bookings')
                .where('userId', isEqualTo: _uid)
                .snapshots()
                .map((snap) {
              final docs = snap.docs.toList()
                ..sort((a, b) {
                  final ta = a.data()['createdAt'];
                  final tb = b.data()['createdAt'];
                  // Rows still waiting on serverTimestamp (or legacy rows
                  // without one) sink to the bottom of a newest-first list.
                  if (ta is! Timestamp) return 1;
                  if (tb is! Timestamp) return -1;
                  return tb.compareTo(ta);
                });
              return docs.map(_bookingFromDoc).toList();
            }));
  }

  Future<void> submitProviderApplication({
    required String type,
    required String businessName,
    required String city,
    String availableFrom = '',
    String availableTo = '',
    String phone = '',
  }) async {
    if (!ready) return;
    final contactPhone =
        phone.isNotEmpty ? phone : (currentUser?.phoneNumber ?? '');
    // The draft listing is created first so the application can point at it;
    // approving flips that listing live.
    // Draft listing, hidden until an admin approves the application.
    final listing = await _db!.collection('providers').add({
      'name': businessName,
      'category': type,
      'subtitle': type == 'delivery' ? 'Delivery partner' : 'New on LocalHive',
      'rating': 5.0,
      'reviews': 0,
      'hourlyRate': type == 'home_service' ? 30.0 : 0.0,
      'city': city,
      'availableFrom': availableFrom,
      'availableTo': availableTo,
      'verified': false,
      'live': false,
      'ownerId': _uid,
      'phone': contactPhone,
      'email': currentUser?.email ?? '',
    });
    await _db!.collection('provider_applications').add({
      'userId': _uid,
      'listingId': listing.id,
      'type': type,
      'businessName': businessName,
      'city': city,
      'availableFrom': availableFrom,
      'availableTo': availableTo,
      'applicantEmail': currentUser?.email ?? '',
      'applicantPhone': contactPhone,
      'status': 'in_review',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---- Admin review console ----

  Future<bool> isAdmin() async {
    if (!ready || currentUser == null) return false;
    try {
      final doc = await _db!.collection('admins').doc(_uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// All provider applications, newest first — admin only (rules enforce it).
  Stream<List<Map<String, dynamic>>> applicationsStream() {
    if (!ready || currentUser == null) return Stream.value(const []);
    return _shared(
        'applications',
        () => _db!.collection('provider_applications').snapshots().map((snap) {
              final docs = snap.docs.toList()
                ..sort((a, b) {
                  final ta = a.data()['createdAt'];
                  final tb = b.data()['createdAt'];
                  // Rows still waiting on serverTimestamp (or legacy rows
                  // without one) sink to the bottom of a newest-first list.
                  if (ta is! Timestamp) return 1;
                  if (tb is! Timestamp) return -1;
                  return tb.compareTo(ta);
                });
              return docs.map((d) => {...d.data(), 'id': d.id}).toList();
            }));
  }

  /// Approve: publish the applicant's listing and tell them the good news.
  Future<void> approveApplication(Map<String, dynamic> app) async {
    if (!ready) return;
    final listingId = (app['listingId'] ?? '') as String;
    if (listingId.isNotEmpty) {
      await _db!.collection('providers').doc(listingId).update({
        'live': true,
        'verified': true,
      });
    }
    await _db!
        .collection('provider_applications')
        .doc(app['id'] as String)
        .update({
      'status': 'approved',
      'reviewedBy': _uid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewNote': '',
    });
    await _notifyApplicant(
        app,
        'LocalHive: your application for "${app['businessName']}" is APPROVED! '
        'Your listing is live — customers can find and book you now. '
        'Open the app to manage orders.');
  }

  /// Decline with a reason the applicant can act on.
  Future<void> rejectApplication(Map<String, dynamic> app, String note) async {
    if (!ready) return;
    await _db!
        .collection('provider_applications')
        .doc(app['id'] as String)
        .update({
      'status': 'rejected',
      'reviewNote': note,
      'reviewedBy': _uid,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    await _notifyApplicant(
        app,
        'LocalHive: we could not approve "${app['businessName']}" yet. '
        'Reason: $note. Reply to this message or reapply once resolved.');
  }

  Future<void> _notifyApplicant(
      Map<String, dynamic> app, String message) async {
    await _db!.collection('notifications').add({
      'recipient': 'applicant',
      'phone': (app['applicantPhone'] ?? '') as String,
      'email': (app['applicantEmail'] ?? '') as String,
      'channels': ['sms', 'email'],
      'event': 'application_reviewed',
      'message': message,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// The signed-in user's own application status (for the Profile card).
  Stream<Map<String, dynamic>?> myApplicationStream() {
    if (!ready || currentUser == null) return Stream.value(null);
    return _shared(
        'myApplication',
        () => _db!
            .collection('provider_applications')
            .where('userId', isEqualTo: _uid)
            .snapshots()
            .map((snap) => snap.docs.isEmpty
                ? null
                : {...snap.docs.first.data(), 'id': snap.docs.first.id}));
  }

  /// Live catalog for one category. Only `live: true` listings are shown.
  /// Equality-only filters use Firestore index merging — no composite index.
  /// One-shot version of [providersStream], for Olivia's tool calls. Returns
  /// `ownerId` alongside each listing because a booking against a listing with
  /// no owner is invisible to every business owner — Olivia must not offer one.
  Future<List<(Provider, String)>> fetchProviders(String category) async {
    if (!ready) return const [];
    try {
      final snap = await _db!
          .collection('providers')
          .where('category', isEqualTo: category)
          .where('live', isEqualTo: true)
          .get();
      return snap.docs.map((d) {
        final m = d.data();
        return (
          Provider(
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
            cuisine: (m['cuisine'] ?? '') as String,
          ),
          (m['ownerId'] ?? '') as String,
        );
      }).toList();
    } catch (e) {
      debugPrint('fetchProviders failed: $e');
      return const [];
    }
  }

  /// Raises a support request Olivia could not resolve herself, and queues a
  /// notification so a human actually follows up.
  Future<String?> createSupportTicket({
    required String subject,
    required String details,
  }) async {
    if (!ready || currentUser == null) return null;
    try {
      final doc = await _db!.collection('support_tickets').add({
        'userId': _uid,
        'subject': subject,
        'details': details,
        'status': 'open',
        'raisedBy': 'olivia',
        'customerEmail': currentUser?.email ?? '',
        'customerName': currentUser?.displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _db!.collection('notifications').add({
        'recipient': 'support',
        'phone': '',
        'email': currentUser?.email ?? '',
        'event': 'support_ticket',
        'message': 'LocalHive support: "$subject" — $details',
        'status': 'pending',
        'ticketId': doc.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    } catch (e) {
      debugPrint('createSupportTicket failed: $e');
      return null;
    }
  }

  Stream<List<Provider>> providersStream(String category) {
    if (!ready) return const Stream.empty();
    return _shared(
        'providers-$category',
        () => _db!
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
                  cuisine: (m['cuisine'] ?? '') as String,
                );
              }).toList()
                ..sort((a, b) => b.rating.compareTo(a.rating));
              return list;
            }));
  }
}
