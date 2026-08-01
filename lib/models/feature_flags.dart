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
  AppFeature(
      'stores', 'Grocery Stores', 'Order groceries for pickup or delivery.'),
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
  AppFeature('messages', 'Messages',
      'In-app text chat between customers, businesses and couriers.'),
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
///
/// Groceries are the only storefront: the food-truck and home-service
/// verticals were removed when LocalHive narrowed to San Francisco.
const defaultFeatureMatrix = <String, Map<String, bool>>{
  'customer': {
    'stores': true,
    'nearby_map': true,
    'olivia': true,
    'bookings': true,
    'become_provider': true,
    'provider_dashboard': false,
    'delivery_jobs': false,
    'messages': true,
  },
  'provider': {
    'stores': true,
    'nearby_map': true,
    'olivia': true,
    'bookings': false,
    'become_provider': false,
    'provider_dashboard': true,
    'delivery_jobs': false,
    'messages': true,
  },
  'delivery': {
    'stores': true,
    'nearby_map': true,
    'olivia': true,
    'bookings': false,
    'become_provider': true,
    'provider_dashboard': false,
    'delivery_jobs': true,
    'messages': true,
  },
};

/// Whether [feature] is on for [role], given admin [overrides] (the
/// config/feature_flags document, possibly empty).
///
/// This resolver deliberately knows nothing about admins. Staff membership is
/// proved against the admins collection by the caller — 'admin' arriving here
/// as a role string would be a claim the user made about themselves on their
/// own profile document.
bool featureEnabledIn(
    Map<String, dynamic> overrides, String role, String feature) {
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
  final v = userOverrides?[feature];
  if (v is bool) return v;
  return featureEnabledIn(roleOverrides, role, feature);
}
