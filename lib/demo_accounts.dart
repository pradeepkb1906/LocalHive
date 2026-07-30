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
      'Book services, order from stores & trucks',
      'demo@localhive.app',
      'demo@123',
      CupertinoIcons.person_fill,
      LhColors.blue),
  DemoAccount(
      'Home service pro',
      'Maria G. — cleaning jobs to accept',
      'maria@localhive.app',
      'maria@123',
      CupertinoIcons.sparkles,
      LhColors.indigo),
  DemoAccount(
      'Food truck owner',
      'Bombay Street Eats — orders & arrival alerts',
      'truck@localhive.app',
      'truck@123',
      CupertinoIcons.car_detailed,
      LhColors.orange),
  DemoAccount(
      'Store owner',
      'Patel Brothers — grocery orders & delivery',
      'store@localhive.app',
      'store@123',
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
      'Review and approve provider applications',
      'admin@localhive.app',
      'admin@123',
      CupertinoIcons.checkmark_shield_fill,
      LhColors.navy),
];
