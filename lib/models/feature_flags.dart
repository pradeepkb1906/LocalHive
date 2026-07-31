/// Role-based feature flags, controlled from the Admin console.
///
/// The admin sees a toggle per (role, feature). ON means the role can use the
/// feature; OFF hides it across the app for everyone in that role. Overrides
/// live in Firestore at config/feature_flags as {role: {feature: bool}};
/// anything not overridden falls back to [defaultFeatureMatrix], which
/// mirrors what each role can do out of the box — so on a fresh install every
/// toggle already sits in the right position. Admins themselves are exempt:
/// the controls must never be able to lock out the person holding them.

class AppFeature {
  final String key;
  final String label;
  final String description;
  const AppFeature(this.key, this.label, this.description);
}

const appFeatures = [
  AppFeature('home_services', 'Home Services',
      'Browse and book cleaners and handymen.'),
  AppFeature('stores', 'Stores',
      'Order groceries and essentials for pickup or delivery.'),
  AppFeature('food_trucks', 'Food Trucks', 'Pre-order from local food trucks.'),
  AppFeature('nearby_map', 'Nearby Now map',
      'Live map of places around you, even beyond partners.'),
  AppFeature('olivia', 'Olivia voice assistant',
      'Order and book by talking to Olivia.'),
  AppFeature('bookings', 'Bookings tab',
      'Order history with live status and cancellation.'),
  AppFeature('become_provider', 'Become a provider',
      'Apply to list a business on LocalHive.'),
  AppFeature('provider_dashboard', 'Provider dashboard',
      'Incoming orders and jobs for business owners.'),
  AppFeature(
      'delivery_jobs', 'Delivery job board', 'Claim and run deliveries.'),
];

/// The roles the admin can configure. Admin itself is deliberately absent.
const featureRoles = ['customer', 'provider', 'delivery'];

const featureRoleLabels = {
  'customer': 'Customer',
  'provider': 'Business owner',
  'delivery': 'Delivery partner',
};

/// What each role can do today, with no overrides — the initial position of
/// every toggle.
const defaultFeatureMatrix = <String, Map<String, bool>>{
  'customer': {
    'home_services': true,
    'stores': true,
    'food_trucks': true,
    'nearby_map': true,
    'olivia': true,
    'bookings': true,
    'become_provider': true,
    'provider_dashboard': false,
    'delivery_jobs': false,
  },
  'provider': {
    'home_services': true,
    'stores': true,
    'food_trucks': true,
    'nearby_map': true,
    'olivia': true,
    'bookings': false,
    'become_provider': false,
    'provider_dashboard': true,
    'delivery_jobs': false,
  },
  'delivery': {
    'home_services': true,
    'stores': true,
    'food_trucks': true,
    'nearby_map': true,
    'olivia': true,
    'bookings': false,
    'become_provider': true,
    'provider_dashboard': false,
    'delivery_jobs': true,
  },
};

/// Whether [feature] is on for [role], given admin [overrides] (the
/// config/feature_flags document, possibly empty). Admin is always allowed —
/// the toggles govern the other roles, and an admin locked out of the
/// console could never undo it.
bool featureEnabledIn(
    Map<String, dynamic> overrides, String role, String feature) {
  if (role == 'admin') return true;
  final roleOverrides = overrides[role];
  if (roleOverrides is Map && roleOverrides[feature] is bool) {
    return roleOverrides[feature] as bool;
  }
  return defaultFeatureMatrix[role]?[feature] ?? false;
}

/// Full resolution for one person, the way staff-permission systems in
/// marketplace apps do it: a per-user override (user_feature_flags/{uid})
/// beats the role setting, which beats the built-in default. No user
/// override for a feature means "follow the role".
bool featureEnabledFor({
  required Map<String, dynamic> roleOverrides,
  Map<String, dynamic>? userOverrides,
  required String role,
  required String feature,
}) {
  if (role == 'admin') return true;
  final v = userOverrides?[feature];
  if (v is bool) return v;
  return featureEnabledIn(roleOverrides, role, feature);
}
