import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Shows one-tap test logins on the sign-in screen.
///
/// Left on because the app is still being demonstrated to shop owners, and
/// switching between customer, owner and courier in front of someone is the
/// whole point of the demo. Set to false before a public launch: these are
/// shared passwords printed on a screen.
///
/// The admin login is deliberately NOT among them — see below.
const bool kShowDemoAccounts = true;

class DemoAccount {
  final String label;
  final String description;
  final String email;
  final String password;
  final IconData icon;
  final Color color;
  const DemoAccount(this.label, this.description, this.email, this.password,
      this.icon, this.color);
}

const demoAccounts = <DemoAccount>[
  DemoAccount(
      'Customer',
      'Browse SF grocery stores and place an order',
      'demo@localhive.app',
      'demo@123',
      CupertinoIcons.person_fill,
      LhColors.blue),
  DemoAccount(
      'SF store owner',
      'Three demo shops — take orders, mark them ready',
      'sfstore@localhive.app',
      'sfstore@123',
      CupertinoIcons.cart_fill,
      LhColors.green),
  DemoAccount(
      'Delivery partner',
      'Claim jobs, navigate, confirm with OTP',
      'delivery@localhive.app',
      'delivery@123',
      CupertinoIcons.cube_box_fill,
      LhColors.orange),
];

/// The platform admin — approves store applications and controls which
/// features each role can reach.
///
/// Kept off the sign-in screen on purpose. The demo is given to shop owners
/// on a phone they can read, and a card printing the admin password would
/// hand every one of them the ability to approve listings and change feature
/// access afterwards. Sign in by typing the address and password instead.
const adminDemoAccount = DemoAccount(
    'Admin',
    'Approve stores and control feature access',
    'admin@localhive.app',
    '',
    CupertinoIcons.checkmark_shield_fill,
    LhColors.navy);
