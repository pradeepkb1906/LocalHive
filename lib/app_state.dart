import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'models/data.dart';
import 'models/feature_flags.dart';
import 'services/firebase_service.dart';

/// App-wide state. Backed by Firebase Auth + Firestore when available;
/// falls back to local in-memory state so the UI never breaks offline.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  final _fb = FirebaseService.instance;

  String? _localName;
  ConfirmationResult? _pendingSms;
  StreamSubscription<List<Booking>>? _bookingsSub;

  List<Booking> bookings = List.of(myBookings);

  String? providerType;
  String? providerBusinessName;
  bool providerKycSubmitted = false;

  /// Account type shapes the whole app: 'customer' | 'provider' | 'delivery'.
  String role = 'customer';

  Future<void> setRole(String r) async {
    role = r;
    notifyListeners();
    await _fb.setRole(r);
  }

  Future<void> _loadRole() async {
    role = await _fb.getRole();
    notifyListeners();
  }

  bool get firebaseReady => _fb.ready;
  bool get signedIn => _fb.currentUser != null || _localName != null;
  String? get userName => _fb.currentUser?.displayName?.isNotEmpty == true
      ? _fb.currentUser!.displayName
      : _localName;
  String? get userPhone => _fb.currentUser?.phoneNumber;

  /// Admin-set overrides of the role/feature matrix; {} until loaded.
  Map<String, dynamic> featureFlags = const {};

  /// Whether the signed-in user's role may use [feature] right now. Admins
  /// are always allowed; everyone else follows the admin's toggles, with the
  /// defaults in feature_flags.dart when nothing has been overridden.
  bool featureEnabled(String feature) =>
      featureEnabledIn(featureFlags, role, feature);

  /// Called once after Firebase init: react to auth changes + live bookings.
  void start() {
    if (!_fb.ready) return;
    _resubscribeFlags();
    FirebaseAuth.instance.authStateChanges().listen((u) {
      _resubscribeBookings();
      // Re-open under the new auth identity: rules only allow signed-in
      // reads of config, so the pre-sign-in stream never yields.
      _resubscribeFlags();
      if (u != null) {
        _loadRole();
      } else {
        role = 'customer';
      }
      notifyListeners();
    });
    _resubscribeBookings();
  }

  StreamSubscription<Map<String, dynamic>>? _flagsSub;

  void _resubscribeFlags() {
    _flagsSub?.cancel();
    _flagsSub = _fb.featureFlagsStream().listen((flags) {
      featureFlags = flags;
      notifyListeners();
    }, onError: (_) {}); // guests just get the defaults
  }

  void _resubscribeBookings() {
    _bookingsSub?.cancel();
    _bookingsSub = _fb.bookingsStream().listen((list) {
      bookings = list;
      notifyListeners();
    }, onError: (_) {}); // guests can't read bookings — keep local list
  }

  /// Normalizes a US number to E.164 (+1XXXXXXXXXX).
  static String normalizeUsPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) return digits;
    if (digits.length == 10) return '+1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return '+$digits';
    return '+$digits';
  }

  /// Step 1 of sign-in: send the SMS code. Returns an error message or null.
  Future<String?> sendCode(String phone) async {
    if (!_fb.ready)
      return null; // offline demo mode: skip straight to code entry
    try {
      _pendingSms = await _fb.sendSmsCode(normalizeUsPhone(phone));
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Could not send the code. Check the number.';
    } catch (e) {
      return 'Could not send the code. Please try again.';
    }
  }

  /// Step 2: verify the code. Returns an error message or null on success.
  Future<String?> verifyCode(String code, String name) async {
    if (!_fb.ready || _pendingSms == null) {
      // Offline demo fallback: accept any 6-digit code.
      _localName = name;
      notifyListeners();
      return null;
    }
    try {
      await _fb.confirmSmsCode(_pendingSms!, code);
      await _fb.setDisplayName(name);
      _pendingSms = null;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Invalid code.';
    } catch (e) {
      return 'Verification failed. Please try again.';
    }
  }

  /// Email/password auth (register with any email, e.g. a Gmail address,
  /// plus a password the user sets). Returns error text or null.
  Future<String?> signUpEmail(
      String email, String password, String name) async {
    if (!_fb.ready) {
      _localName = name;
      notifyListeners();
      return null;
    }
    final err = await _fb.signUpWithEmail(email, password, name);
    if (err == null) notifyListeners();
    return err;
  }

  Future<String?> signInEmail(String email, String password) async {
    if (!_fb.ready) return 'Offline — use phone demo sign-in.';
    final err = await _fb.signInWithEmail(email, password);
    if (err == null) notifyListeners();
    return err;
  }

  String? get userEmail => _fb.currentUser?.email;

  Future<String?> sendPasswordReset(String email) =>
      _fb.sendPasswordReset(email);

  Future<void> signOut() async {
    _localName = null;
    await _fb.signOut();
    notifyListeners();
  }

  void addBooking(Booking b) {
    bookings = [b, ...bookings];
    notifyListeners();
    // Fire-and-forget persist; the stream will reconcile ordering.
    unawaited(_fb.addBooking(b));
  }

  /// Same write, but awaits Firestore and hands back the new booking id.
  /// Olivia uses this so she can tell the customer their order is really in
  /// and then track it; the tap-driven screens keep using [addBooking].
  Future<String?> addBookingAndWait(Booking b) async {
    bookings = [b, ...bookings];
    notifyListeners();
    return _fb.addBooking(b);
  }

  Future<void> submitProviderApplication(
      {required String type,
      required String businessName,
      String city = '',
      String availableFrom = '',
      String availableTo = ''}) async {
    providerType = type;
    providerBusinessName = businessName;
    providerKycSubmitted = true;
    notifyListeners();
    unawaited(_fb.submitProviderApplication(
        type: type,
        businessName: businessName,
        city: city,
        availableFrom: availableFrom,
        availableTo: availableTo));
  }
}
