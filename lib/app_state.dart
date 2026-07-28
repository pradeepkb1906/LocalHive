import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'models/data.dart';
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

  bool get firebaseReady => _fb.ready;
  bool get signedIn => _fb.currentUser != null || _localName != null;
  String? get userName =>
      _fb.currentUser?.displayName?.isNotEmpty == true ? _fb.currentUser!.displayName : _localName;
  String? get userPhone => _fb.currentUser?.phoneNumber;

  /// Called once after Firebase init: react to auth changes + live bookings.
  void start() {
    if (!_fb.ready) return;
    FirebaseAuth.instance.authStateChanges().listen((_) {
      _resubscribeBookings();
      notifyListeners();
    });
    _resubscribeBookings();
  }

  void _resubscribeBookings() {
    _bookingsSub?.cancel();
    _bookingsSub = _fb.bookingsStream().listen((list) {
      bookings = list;
      notifyListeners();
    });
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
    if (!_fb.ready) return null; // offline demo mode: skip straight to code entry
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

  Future<void> submitProviderApplication(
      {required String type, required String businessName, String city = ''}) async {
    providerType = type;
    providerBusinessName = businessName;
    providerKycSubmitted = true;
    notifyListeners();
    unawaited(_fb.submitProviderApplication(type: type, businessName: businessName, city: city));
  }
}
