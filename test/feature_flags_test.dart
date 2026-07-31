import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/models/feature_flags.dart';

// The admin's role/feature toggle matrix: defaults must mirror what each
// role can already do, overrides must win, and the admin must be immune.
void main() {
  test('defaults mirror current role access', () {
    // Customer: full storefront, no operator surfaces.
    expect(featureEnabledIn(const {}, 'customer', 'home_services'), isTrue);
    expect(featureEnabledIn(const {}, 'customer', 'bookings'), isTrue);
    expect(featureEnabledIn(const {}, 'customer', 'olivia'), isTrue);
    expect(
        featureEnabledIn(const {}, 'customer', 'provider_dashboard'), isFalse);
    expect(featureEnabledIn(const {}, 'customer', 'delivery_jobs'), isFalse);
    // Provider: dashboard on, customer bookings tab off.
    expect(
        featureEnabledIn(const {}, 'provider', 'provider_dashboard'), isTrue);
    expect(featureEnabledIn(const {}, 'provider', 'bookings'), isFalse);
    // Delivery: job board on.
    expect(featureEnabledIn(const {}, 'delivery', 'delivery_jobs'), isTrue);
  });

  test('an admin override beats the default', () {
    final overrides = {
      'customer': {'olivia': false, 'provider_dashboard': true}
    };
    expect(featureEnabledIn(overrides, 'customer', 'olivia'), isFalse);
    expect(
        featureEnabledIn(overrides, 'customer', 'provider_dashboard'), isTrue);
    // Untouched features keep their defaults.
    expect(featureEnabledIn(overrides, 'customer', 'stores'), isTrue);
  });

  test('the admin role is never affected by any toggle', () {
    final everythingOff = {
      for (final role in featureRoles)
        role: {for (final f in appFeatures) f.key: false}
    };
    for (final f in appFeatures) {
      expect(featureEnabledIn(everythingOff, 'admin', f.key), isTrue,
          reason: 'admin must keep ${f.key} or could lock themselves out');
    }
  });

  test('a per-user override beats the role setting, which beats the default',
      () {
    final roleOverrides = {
      'provider': {'olivia': false}
    };
    // No user override: the role setting wins over the default.
    expect(
        featureEnabledFor(
            roleOverrides: roleOverrides,
            userOverrides: const {},
            role: 'provider',
            feature: 'olivia'),
        isFalse);
    // A user override wins over the role setting.
    expect(
        featureEnabledFor(
            roleOverrides: roleOverrides,
            userOverrides: const {'olivia': true},
            role: 'provider',
            feature: 'olivia'),
        isTrue);
    // A user override can also take away what the role grants.
    expect(
        featureEnabledFor(
            roleOverrides: const {},
            userOverrides: const {'stores': false},
            role: 'customer',
            feature: 'stores'),
        isFalse);
    // Untouched features follow the role as before.
    expect(
        featureEnabledFor(
            roleOverrides: roleOverrides,
            userOverrides: const {'olivia': true},
            role: 'provider',
            feature: 'provider_dashboard'),
        isTrue);
    // Admin stays immune even with a hostile user override.
    expect(
        featureEnabledFor(
            roleOverrides: const {},
            userOverrides: const {'stores': false},
            role: 'admin',
            feature: 'stores'),
        isTrue);
  });

  test('unknown roles and features fail closed', () {
    expect(featureEnabledIn(const {}, 'customer', 'no_such_feature'), isFalse);
    expect(featureEnabledIn(const {}, 'no_such_role', 'stores'), isFalse);
  });

  test('every feature has a default position for every configurable role', () {
    for (final role in featureRoles) {
      for (final f in appFeatures) {
        expect(defaultFeatureMatrix[role]!.containsKey(f.key), isTrue,
            reason: '$role is missing a default for ${f.key}');
      }
    }
  });
}
