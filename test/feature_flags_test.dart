import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/models/feature_flags.dart';

// The admin's role/feature toggle matrix: defaults must mirror what each
// role can already do, overrides must win, and the admin must be immune.
void main() {
  test('defaults mirror current role access', () {
    // Customer: focused on the one live vertical (SF groceries); the other
    // two storefronts ship off until there is real supply behind them.
    expect(featureEnabledIn(const {}, 'customer', 'stores'), isTrue);
    expect(featureEnabledIn(const {}, 'customer', 'home_services'), isFalse);
    expect(featureEnabledIn(const {}, 'customer', 'food_trucks'), isFalse);
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
    // Chat ships on for every role.
    for (final role in featureRoles) {
      expect(featureEnabledIn(const {}, role, 'messages'), isTrue,
          reason: 'messages should default on for $role');
    }
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

  test('the resolver grants nothing on the strength of a role string', () {
    // 'admin' used to short-circuit to true here. It cannot any more: role
    // lives on users/{uid}, which the user themselves may write, so anyone
    // could have claimed it. Staff membership is proved against the admins
    // collection by AppState before this is ever consulted.
    final everythingOff = {
      for (final r in featureRoles)
        r: {for (final f in appFeatures) f.key: false}
    };
    for (final f in appFeatures) {
      expect(featureEnabledIn(everythingOff, 'admin', f.key), isFalse,
          reason: 'a self-declared role must not unlock ${f.key}');
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
    // A user override applies whatever the role claims to be — including
    // 'admin'. Real staff bypass this resolver entirely, via proved
    // membership of the admins collection, so nothing here needs to trust a
    // role string a user can write for themselves.
    expect(
        featureEnabledFor(
            roleOverrides: const {},
            userOverrides: const {'stores': false},
            role: 'admin',
            feature: 'stores'),
        isFalse);
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
