import 'package:flutter/foundation.dart';
import 'models/data.dart';

/// Session-level app state (mock auth + live bookings).
/// Swapped for Firebase Auth + Firestore in the production milestone;
/// the notifier API stays the same so screens don't change.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  String? userName;
  String? userPhone;
  bool get signedIn => userName != null;

  final List<Booking> bookings = List.of(myBookings);

  // Provider-onboarding draft (Become a provider wizard).
  String? providerType;
  String? providerBusinessName;
  bool providerKycSubmitted = false;

  void signIn(String name, String phone) {
    userName = name;
    userPhone = phone;
    notifyListeners();
  }

  void signOut() {
    userName = null;
    userPhone = null;
    notifyListeners();
  }

  void addBooking(Booking b) {
    bookings.insert(0, b);
    notifyListeners();
  }

  void submitProviderApplication({required String type, required String businessName}) {
    providerType = type;
    providerBusinessName = businessName;
    providerKycSubmitted = true;
    notifyListeners();
  }
}
