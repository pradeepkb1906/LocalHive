import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Set to false before a public launch — this exposes shared test logins,
/// including the admin account, on the sign-in screen.
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
  DemoAccount(
      'Admin',
      'Approve stores and control feature access',
      'admin@localhive.app',
      'admin@123',
      CupertinoIcons.checkmark_shield_fill,
      LhColors.navy),
];
