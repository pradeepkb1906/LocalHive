import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/speech/speech_engine.dart';

import '../theme.dart';
import 'system_check_screen.dart';

/// Kinds of mock UI the tour can draw inside the phone frame.
enum _B { row, banner, button, chips, field, segments, sms, otp, note, map }

class _Block {
  final _B type;
  final IconData? icon;
  final Color? color;
  final String? title;
  final String? subtitle;
  final String? trailing;
  final List<String>? options;
  final int selected;
  const _Block(
    this.type, {
    this.icon,
    this.color,
    this.title,
    this.subtitle,
    this.trailing,
    this.options,
    this.selected = 0,
  });
}

class _Mock {
  final String appBar;
  final List<_Block> blocks;
  final int highlight; // index into blocks, -1 for none
  const _Mock(this.appBar, this.blocks, {this.highlight = -1});
}

class _Step {
  final String persona;
  final Color color;
  final IconData personaIcon;
  final String title;
  final String narration;
  final _Mock mock;
  const _Step(this.persona, this.color, this.personaIcon, this.title,
      this.narration, this.mock);
}

const _cust = 'Customer';
const _own = 'Business owner';
const _del = 'Delivery partner';
const _adm = 'Admin';
const _cIcon = CupertinoIcons.person_fill;
const _oIcon = CupertinoIcons.briefcase_fill;
const _dIcon = CupertinoIcons.cube_box_fill;
const _aIcon = CupertinoIcons.checkmark_shield_fill;

final _steps = <_Step>[
  // ═══════════ Getting started ═══════════
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Welcome to LocalHive',
      'LocalHive brings three local services into one app: home services like '
          'cleaning and handyman work, Indian grocery stores, and food trucks. '
          'This tour walks you through every flow, step by step.',
      _Mock('LocalHive', [
        _Block(_B.row,
            icon: CupertinoIcons.sparkles,
            color: LhColors.indigo,
            title: 'Home Services',
            subtitle: 'Cleaners & handymen, background-checked'),
        _Block(_B.row,
            icon: CupertinoIcons.cart_fill,
            color: LhColors.green,
            title: 'Indian Stores',
            subtitle: 'Groceries & essentials'),
        _Block(_B.row,
            icon: CupertinoIcons.car_detailed,
            color: LhColors.orange,
            title: 'Food Trucks',
            subtitle: 'Live locations, skip the line'),
      ])),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 1 — Create your account',
      'First, tap Sign In on the Profile tab. You can register with your email '
          'address, like a Gmail account, and a password you choose. There is '
          'also a phone option that texts you a six digit code.',
      _Mock(
          'Sign In',
          [
            _Block(_B.segments, options: ['Email', 'Phone'], selected: 0),
            _Block(_B.field, title: 'Full name'),
            _Block(_B.field, title: 'Email (e.g. you@gmail.com)'),
            _Block(_B.field, title: 'Password (6+ characters)'),
            _Block(_B.button, title: 'Create Account'),
          ],
          highlight: 4)),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 2 — Pick how you will use the app',
      'Right after signing up you choose your account type. Customer to book '
          'and order. Business owner if you run a service, store, or truck. '
          'Delivery partner if you want to earn delivering orders. You can '
          'switch anytime from your Profile.',
      _Mock(
          'How will you use LocalHive?',
          [
            _Block(_B.row,
                icon: _cIcon,
                color: LhColors.blue,
                title: 'Customer',
                subtitle: 'Book services, order from stores & trucks'),
            _Block(_B.row,
                icon: _oIcon,
                color: LhColors.indigo,
                title: 'Business owner',
                subtitle: 'Manage your orders and listings'),
            _Block(_B.row,
                icon: _dIcon,
                color: LhColors.orange,
                title: 'Delivery partner',
                subtitle: 'Claim and deliver orders'),
          ],
          highlight: 0)),
  // ═══════════ Customer — Home services ═══════════
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 3 — Open Home Services',
      'Let us book a house cleaning. From the home screen, tap Home Services. '
          'The flag chip at the top right shows your area, detected from your '
          'phone location or your internet connection.',
      _Mock(
          'LocalHive',
          [
            _Block(_B.row,
                icon: CupertinoIcons.sparkles,
                color: LhColors.indigo,
                title: 'Home Services',
                subtitle: 'Book 3–4 hour visits'),
            _Block(_B.row,
                icon: CupertinoIcons.cart_fill,
                color: LhColors.green,
                title: 'Indian Stores',
                subtitle: 'Pickup or delivery'),
            _Block(_B.row,
                icon: CupertinoIcons.car_detailed,
                color: LhColors.orange,
                title: 'Food Trucks',
                subtitle: 'Pre-order ahead'),
          ],
          highlight: 0)),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 4 — Choose a verified pro',
      'You see each provider\'s rating, number of reviews, hourly rate, and '
          'the hours they are available. The blue tick means they are ID '
          'verified and background checked. Tap Maria.',
      _Mock(
          'Home Services',
          [
            _Block(_B.row,
                icon: _cIcon,
                color: LhColors.indigo,
                title: 'Maria G. ✓',
                subtitle: '⭐ 4.9 (212) · Available 8 AM – 6 PM · Edison, NJ',
                trailing: '\$28/hr'),
            _Block(_B.row,
                icon: _cIcon,
                color: LhColors.indigo,
                title: 'Dave R. ✓',
                subtitle: '⭐ 4.8 (158) · Handyman · Edison, NJ',
                trailing: '\$45/hr'),
            _Block(_B.row,
                icon: _cIcon,
                color: LhColors.indigo,
                title: 'Lakshmi P. ✓',
                subtitle: '⭐ 4.7 (96) · Move-in cleaning',
                trailing: '\$30/hr'),
          ],
          highlight: 0)),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 5 — Pick your day',
      'Choose which day you want the visit. Today, tomorrow, or up to four '
          'days ahead. Tap Tomorrow.',
      _Mock(
          'Maria G.',
          [
            _Block(_B.note, title: 'DAY'),
            _Block(_B.chips,
                options: ['Today', 'Tomorrow', 'In 2 days', 'In 3 days'],
                selected: 1),
            _Block(_B.note, title: 'START TIME'),
            _Block(_B.chips,
                options: ['8:00 AM', '10:00 AM', '1:00 PM', '3:00 PM'],
                selected: 1),
          ],
          highlight: 1)),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 6 — Pick time and duration',
      'Now choose the start time and how many hours you need. Most cleanings '
          'take three or four hours. Tap ten A M, then three hours.',
      _Mock(
          'Maria G.',
          [
            _Block(_B.note, title: 'START TIME'),
            _Block(_B.chips,
                options: ['8:00 AM', '10:00 AM', '1:00 PM', '3:00 PM'],
                selected: 1),
            _Block(_B.note, title: 'DURATION'),
            _Block(_B.chips, options: ['3 hours', '4 hours'], selected: 0),
          ],
          highlight: 3)),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 7 — Where should the pro come?',
      'Enter the address where you want the service, plus your name, mobile '
          'number and email. Your mobile is how we text you updates, and how '
          'the provider can reach you if needed.',
      _Mock(
          'Maria G.',
          [
            _Block(_B.note, title: 'SERVICE ADDRESS & CONTACT'),
            _Block(_B.field, title: '45 Oak Tree Road, Edison, NJ 08820'),
            _Block(_B.field, title: 'Your name'),
            _Block(_B.field, title: 'Mobile (SMS updates)'),
          ],
          highlight: 1)),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 8 — See the full price, then book',
      'Before you pay, LocalHive shows the maths: three hours at twenty eight '
          'dollars is eighty four dollars, plus a flat twelve percent platform '
          'fee. Maria receives the full eighty four dollars. You are only '
          'charged after the job is done. Tap Book.',
      _Mock(
          'Maria G.',
          [
            _Block(_B.row,
                icon: CupertinoIcons.money_dollar_circle_fill,
                color: LhColors.navy,
                title: '3 hrs × \$28/hr',
                trailing: '\$84.00'),
            _Block(_B.row,
                icon: CupertinoIcons.percent,
                color: LhColors.navy,
                title: 'Platform fee (12%)',
                trailing: '\$10.08'),
            _Block(_B.row,
                icon: CupertinoIcons.checkmark_seal_fill,
                color: LhColors.green,
                title: 'Total',
                subtitle: 'Maria receives \$84.00 after completion',
                trailing: '\$94.08'),
            _Block(_B.button, title: 'Book for \$94.08'),
          ],
          highlight: 3)),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 9 — Your request is sent',
      'Maria is notified instantly by WhatsApp or text message. You get a '
          'confirmation too. Nobody has to call anybody.',
      _Mock(
          'Request sent',
          [
            _Block(_B.sms,
                title: 'To Maria',
                subtitle:
                    'LocalHive: NEW JOB REQUEST — House cleaning · Tomorrow 10:00 AM '
                    '· 3 hrs at 45 Oak Tree Road, Edison. Open your Provider '
                    'Dashboard to accept.'),
            _Block(_B.sms,
                title: 'To you',
                subtitle:
                    'LocalHive: your request to Maria G. was sent. We will notify '
                    'you when it is accepted.'),
          ],
          highlight: 0)),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 10 — Track it in Bookings',
      'The Bookings tab shows every booking and order with its live status: '
          'requested, accepted, on the way, and completed.',
      _Mock(
          'Bookings',
          [
            _Block(_B.row,
                icon: CupertinoIcons.calendar_badge_plus,
                color: LhColors.indigo,
                title: 'Maria G.',
                subtitle: 'House cleaning · Tomorrow 10 AM · 3 hrs',
                trailing: 'Accepted'),
          ],
          highlight: 0)),
  // ═══════════ Customer — Indian store ═══════════
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 11 — Order groceries',
      'Now a grocery order. Tap Indian Stores and pick your shop. You see '
          'ratings and what each store specialises in.',
      _Mock(
          'Indian Stores',
          [
            _Block(_B.row,
                icon: CupertinoIcons.cart_fill,
                color: LhColors.green,
                title: 'Patel Brothers Express',
                subtitle: '⭐ 4.8 (431) · Groceries, spices, fresh produce'),
            _Block(_B.row,
                icon: CupertinoIcons.cart_fill,
                color: LhColors.green,
                title: 'Desi Bazaar',
                subtitle: '⭐ 4.6 (189) · Snacks, sweets, pooja items'),
          ],
          highlight: 0)),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 12 — Add items to your cart',
      'Tap Add on anything you need. Use plus and minus to change quantities. '
          'The cart total updates live at the bottom of the screen.',
      _Mock(
          'Patel Brothers Express',
          [
            _Block(_B.row,
                icon: CupertinoIcons.bag_fill,
                color: LhColors.green,
                title: 'Basmati Rice 10 lb',
                subtitle: '\$14.99 / bag',
                trailing: 'Add'),
            _Block(_B.row,
                icon: CupertinoIcons.bag_fill,
                color: LhColors.green,
                title: 'Toor Dal 4 lb',
                subtitle: '\$7.49 / bag',
                trailing: '1'),
            _Block(_B.button, title: 'View Cart · 2 items · \$25.14'),
          ],
          highlight: 0)),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 13 — Pickup or delivery?',
      'Choose Pickup to collect it yourself, or Delivery for four dollars '
          'ninety nine. If you pick up, tell the store when you will arrive so '
          'your order is ready and waiting.',
      _Mock(
          'Order · Patel Brothers',
          [
            _Block(_B.segments,
                options: ['Pickup', 'Delivery +\$4.99'], selected: 0),
            _Block(_B.note, title: 'WHEN WILL YOU ARRIVE?'),
            _Block(_B.chips,
                options: ['In 15 min', 'In 30 min', 'In 45 min'], selected: 1),
          ],
          highlight: 0)),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 14 — Delivery address and total',
      'If you chose delivery, enter your address. The total shows your items, '
          'the twelve percent platform fee, and the delivery fee — no '
          'surprises. Tap Place Delivery Order.',
      _Mock(
          'Order · Patel Brothers',
          [
            _Block(_B.field, title: 'Delivery address (street, city, state)'),
            _Block(_B.row,
                icon: CupertinoIcons.percent,
                color: LhColors.navy,
                title: 'Platform fee (12%)',
                trailing: '\$3.02'),
            _Block(_B.row,
                icon: CupertinoIcons.cube_box_fill,
                color: LhColors.orange,
                title: 'Delivery fee',
                trailing: '\$4.99'),
            _Block(_B.button, title: 'Place Delivery Order · \$33.15'),
          ],
          highlight: 3)),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 15 — Save your delivery code',
      'For deliveries you get a four digit code by text. Give this code to the '
          'delivery partner only when your order actually arrives. It proves '
          'the food reached you and protects everyone.',
      _Mock(
          'Your delivery OTP',
          [
            _Block(_B.otp, title: '4 7 2 9'),
            _Block(_B.sms,
                title: 'Text message',
                subtitle:
                    'LocalHive: your order at Patel Brothers is placed. Your '
                    'delivery OTP is 4729 — share it ONLY when your order arrives.'),
          ],
          highlight: 0)),
  // ═══════════ Customer — Food truck ═══════════
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 16 — Find food trucks near you',
      'Tap Food Trucks, then the Map button to see every truck pinned on a '
          'live map. Tap a pin to open that truck\'s menu.',
      _Mock(
          'Food Trucks',
          [
            _Block(_B.map, title: 'Bombay Street Eats · Oak Tree Rd, Edison'),
            _Block(_B.row,
                icon: CupertinoIcons.car_detailed,
                color: LhColors.orange,
                title: 'Bombay Street Eats ✓',
                subtitle: '⭐ 4.9 (310) · Vada pav, pav bhaji · open till 9 PM'),
          ],
          highlight: 0)),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 17 — Get told when the truck arrives',
      'Tap the bell on any truck to follow it. Enter your mobile number, and '
          'the moment that truck parks nearby you get a text telling you '
          'exactly where it is. No more guessing.',
      _Mock(
          'Bombay Street Eats',
          [
            _Block(_B.row,
                icon: CupertinoIcons.bell_fill,
                color: LhColors.orange,
                title: 'Alert me when this truck arrives',
                subtitle: 'We text you the moment it parks nearby'),
            _Block(_B.field, title: 'Mobile number for the alert'),
            _Block(_B.button, title: 'Notify Me'),
          ],
          highlight: 0)),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 18 — Pre-order and skip the line',
      'Add what you want, choose pickup, and tell them when you are coming. '
          'Your food is hot and bagged when you walk up — no queue.',
      _Mock(
          'Bombay Street Eats',
          [
            _Block(_B.row,
                icon: CupertinoIcons.bag_fill,
                color: LhColors.orange,
                title: 'Chicken Biryani',
                subtitle: '\$12.99 / box',
                trailing: '1'),
            _Block(_B.row,
                icon: CupertinoIcons.bag_fill,
                color: LhColors.orange,
                title: 'Masala Chai',
                subtitle: '\$2.50 / cup',
                trailing: 'Add'),
            _Block(_B.button, title: 'Place Pickup Order · \$14.55'),
          ],
          highlight: 2)),
  const _Step(
      _cust,
      LhColors.blue,
      _cIcon,
      'Step 19 — The truck texts you',
      'When the owner announces arrival, every follower gets this message '
          'instantly — with the exact street corner.',
      _Mock(
          'Arrival alert',
          [
            _Block(_B.sms,
                title: 'Text message',
                subtitle:
                    'LocalHive: Bombay Street Eats has ARRIVED at Oak Tree Rd & '
                    'Wood Ave — come grab your favourites or pre-order in the app '
                    'to skip the line!'),
          ],
          highlight: 0)),
  // ═══════════ Business owner ═══════════
  const _Step(
      _own,
      LhColors.indigo,
      _oIcon,
      'Step 20 — Apply to list your business',
      'Now the business side. From Profile, tap Become a provider and choose '
          'what you offer: home services, an Indian store, a food truck, or '
          'delivery.',
      _Mock(
          'Become a Provider',
          [
            _Block(_B.row,
                icon: CupertinoIcons.sparkles,
                color: LhColors.indigo,
                title: 'Home services',
                subtitle: 'Cleaning, handyman work'),
            _Block(_B.row,
                icon: CupertinoIcons.cart_fill,
                color: LhColors.green,
                title: 'Indian store',
                subtitle: 'Grocery or retail with pickup / delivery'),
            _Block(_B.row,
                icon: CupertinoIcons.car_detailed,
                color: LhColors.orange,
                title: 'Food truck',
                subtitle: 'Mobile food with live location'),
          ],
          highlight: 2)),
  const _Step(
      _own,
      LhColors.indigo,
      _oIcon,
      'Step 21 — Your business details and hours',
      'Enter your business name and city, then set the hours you are '
          'available, from and to. Customers see this window, and you only get '
          'jobs inside it.',
      _Mock(
          'Your business',
          [
            _Block(_B.field, title: 'Business name (e.g. Bombay Street Eats)'),
            _Block(_B.field, title: 'City, State (e.g. Edison, NJ)'),
            _Block(_B.note, title: 'I AM AVAILABLE'),
            _Block(_B.chips, options: ['From 10 AM', 'To 9 PM'], selected: 0),
          ],
          highlight: 3)),
  const _Step(
      _own,
      LhColors.indigo,
      _oIcon,
      'Step 22 — Verification and submit',
      'You confirm you operate as an independent business responsible for your '
          'own licences and taxes, and you consent to identity verification — '
          'plus a background check for home services. Then submit.',
      _Mock(
          'Verification',
          [
            _Block(_B.row,
                icon: CupertinoIcons.person_badge_plus_fill,
                color: LhColors.blue,
                title: 'Identity check (KYC)',
                subtitle:
                    'Government ID + selfie; sets up your payout account'),
            _Block(_B.row,
                icon: CupertinoIcons.doc_checkmark_fill,
                color: LhColors.green,
                title: 'Background check',
                subtitle: 'Home services only, with your written consent'),
            _Block(_B.button, title: 'Submit Application'),
          ],
          highlight: 2)),
  const _Step(
      _own,
      LhColors.indigo,
      _oIcon,
      'Step 23 — Wait for approval',
      'Your Profile shows the live status of your application while the '
          'LocalHive team reviews it. You get a text the moment it is decided.',
      _Mock(
          'Profile',
          [
            _Block(_B.row,
                icon: CupertinoIcons.clock_fill,
                color: LhColors.orange,
                title: 'Application under review',
                subtitle: 'Bombay Street Eats — verifying your details'),
          ],
          highlight: 0)),
  const _Step(
      _own,
      LhColors.indigo,
      _oIcon,
      'Step 24 — Approved, you are live',
      'Once approved, your listing is published to the public catalog '
          'instantly and customers can find and book you.',
      _Mock(
          'Approved',
          [
            _Block(_B.sms,
                title: 'Text message',
                subtitle:
                    'LocalHive: your application for "Bombay Street Eats" is '
                    'APPROVED! Your listing is live — customers can find and book '
                    'you now.'),
            _Block(_B.row,
                icon: CupertinoIcons.checkmark_seal_fill,
                color: LhColors.green,
                title: 'Application approved',
                subtitle: 'Bombay Street Eats is live'),
          ],
          highlight: 0)),
  const _Step(
      _own,
      LhColors.indigo,
      _oIcon,
      'Step 25 — Orders come to you',
      'When you sign in, LocalHive opens straight on your Dashboard, and this '
          'banner tells you how many orders are waiting. The Dashboard tab '
          'also carries a live count badge.',
      _Mock(
          'LocalHive',
          [
            _Block(_B.banner,
                title: '2 orders waiting — tap to open your Dashboard'),
            _Block(_B.row,
                icon: CupertinoIcons.sparkles,
                color: LhColors.indigo,
                title: 'Browse as a customer too',
                subtitle: 'Your customer view still works'),
          ],
          highlight: 0)),
  const _Step(
      _own,
      LhColors.indigo,
      _oIcon,
      'Step 26 — Read the job, get directions',
      'Every card shows the customer\'s name and phone, the service address '
          'with a Directions button that pins it on a map, when they are '
          'arriving for pickups, and exactly what you earn after the platform '
          'fee.',
      _Mock(
          'Provider Dashboard',
          [
            _Block(_B.row,
                icon: CupertinoIcons.location_solid,
                color: LhColors.navy,
                title: '45 Oak Tree Road, Edison, NJ',
                subtitle: 'Tap Directions to navigate',
                trailing: 'Directions'),
            _Block(_B.row,
                icon: _cIcon,
                color: LhColors.navy,
                title: 'Demo Customer',
                subtitle: '+1 732 555 0123'),
            _Block(_B.row,
                icon: CupertinoIcons.money_dollar_circle_fill,
                color: LhColors.green,
                title: 'You earn \$84.00',
                subtitle: 'Customer pays \$94.08'),
          ],
          highlight: 0)),
  const _Step(
      _own,
      LhColors.indigo,
      _oIcon,
      'Step 27 — Accept the job',
      'Tap Accept and the customer is texted immediately that you are coming. '
          'Or Decline, and they are told to choose someone else.',
      _Mock(
          'Provider Dashboard',
          [
            _Block(_B.row,
                icon: CupertinoIcons.doc_text_fill,
                color: LhColors.orange,
                title: 'House cleaning · Tomorrow 10 AM · 3 hrs',
                subtitle: 'You earn \$84.00',
                trailing: 'Requested'),
            _Block(_B.button, title: 'Accept'),
          ],
          highlight: 1)),
  const _Step(
      _own,
      LhColors.indigo,
      _oIcon,
      'Step 28 — Move the order along',
      'For store and truck orders you tap through the stages: Accept and start '
          'Preparing, then Mark Ready, then Delivered or handed over. Each tap '
          'texts the customer automatically.',
      _Mock(
          'Provider Dashboard',
          [
            _Block(_B.row,
                icon: CupertinoIcons.bag_fill,
                color: LhColors.orange,
                title: 'Pickup order · 2 items',
                subtitle: 'Customer arriving: In 30 min',
                trailing: 'Preparing'),
            _Block(_B.button, title: 'Mark Ready for Pickup'),
          ],
          highlight: 1)),
  const _Step(
      _own,
      LhColors.indigo,
      _oIcon,
      'Step 29 — Send a delivery to the board',
      'If the order is for delivery, marking it Ready posts it to the delivery '
          'job board where any partner nearby can claim it.',
      _Mock(
          'Provider Dashboard',
          [
            _Block(_B.row,
                icon: CupertinoIcons.cube_box_fill,
                color: LhColors.orange,
                title: 'Delivery order · 1 item',
                subtitle: 'Deliver to 456 Wood Ave, Iselin',
                trailing: 'Ready'),
            _Block(_B.button, title: 'Mark Ready & Request Delivery Partner'),
          ],
          highlight: 1)),
  const _Step(
      _own,
      LhColors.indigo,
      _oIcon,
      'Step 30 — Food trucks: announce you have arrived',
      'Tap the megaphone on your Dashboard, type where you are parked, and '
          'every customer following your truck is texted instantly. The dialog '
          'even tells you how many followers will hear it.',
      _Mock(
          'Announce arrival',
          [
            _Block(_B.note, title: '12 customers follow Bombay Street Eats'),
            _Block(_B.field,
                title: 'Where are you? (e.g. Oak Tree Rd & Wood Ave)'),
            _Block(_B.button, title: 'Announce'),
          ],
          highlight: 2)),
  // ═══════════ Delivery partner ═══════════
  const _Step(
      _del,
      LhColors.orange,
      _dIcon,
      'Step 31 — Register as a delivery partner',
      'Students and gig workers can sign up to deliver. Choose Delivery '
          'partner, then set the hours you are free — for example five P M to '
          'ten P M after classes.',
      _Mock(
          'Become a Provider',
          [
            _Block(_B.row,
                icon: _dIcon,
                color: LhColors.blue,
                title: 'Delivery partner',
                subtitle:
                    'Students & gig workers — deliver on your own schedule'),
            _Block(_B.note, title: 'I AM AVAILABLE'),
            _Block(_B.chips, options: ['From 5 PM', 'To 10 PM'], selected: 0),
          ],
          highlight: 0)),
  const _Step(
      _del,
      LhColors.orange,
      _dIcon,
      'Step 32 — Your delivery board',
      'Once approved, the Deliveries tab shows two numbers at a glance: how '
          'many deliveries you are already carrying, and how many jobs are '
          'open to claim right now.',
      _Mock(
          'Delivery Jobs',
          [
            _Block(_B.row,
                icon: _dIcon,
                color: LhColors.navy,
                title: 'My deliveries: 1',
                subtitle: 'Open to claim: 3'),
            _Block(_B.row,
                icon: CupertinoIcons.bag_fill,
                color: LhColors.orange,
                title: 'Patel Brothers Express',
                subtitle: 'Deliver to 456 Wood Ave, Iselin',
                trailing: '\$4.99'),
          ],
          highlight: 0)),
  const _Step(
      _del,
      LhColors.orange,
      _dIcon,
      'Step 33 — Grab jobs on your route',
      'Jobs going the same way as a delivery you already have are marked "On '
          'your way". Claim two and earn twice in one trip.',
      _Mock(
          'Delivery Jobs',
          [
            _Block(_B.row,
                icon: CupertinoIcons.bag_fill,
                color: LhColors.orange,
                title: 'Desi Bazaar · On your way!',
                subtitle: 'Deliver to 460 Wood Ave, Iselin',
                trailing: '\$4.99'),
            _Block(_B.button, title: 'Claim This Delivery'),
          ],
          highlight: 1)),
  const _Step(
      _del,
      LhColors.orange,
      _dIcon,
      'Step 34 — Navigate and pick up',
      'After claiming, you get the store address and the customer\'s address, '
          'each with a Directions button and the customer\'s phone number. Tap '
          'Mark Picked Up when you have the order — the customer is told you '
          'are on the way.',
      _Mock(
          'Delivery Jobs',
          [
            _Block(_B.row,
                icon: CupertinoIcons.location_solid,
                color: LhColors.navy,
                title: 'Deliver to: 456 Wood Ave, Iselin',
                subtitle: 'Customer: +1 732 555 0123',
                trailing: 'Directions'),
            _Block(_B.button, title: 'Mark Picked Up'),
          ],
          highlight: 1)),
  const _Step(
      _del,
      LhColors.orange,
      _dIcon,
      'Step 35 — Finish with the customer\'s code',
      'At the door, ask for the four digit code from their order message and '
          'type it in. A wrong code is rejected. Once it matches, the delivery '
          'is complete and your fee is queued for payout.',
      _Mock(
          'Confirm delivery',
          [
            _Block(_B.otp, title: '4 7 2 9'),
            _Block(_B.button, title: 'Confirm Delivery'),
          ],
          highlight: 0)),
  // ═══════════ Admin ═══════════
  const _Step(
      _adm,
      LhColors.green,
      _aIcon,
      'Step 36 — The admin reviews everyone',
      'Finally, the platform owner. Every application to offer services, sell '
          'groceries, run a truck, or deliver arrives in the Review tab, and '
          'the badge shows how many are waiting.',
      _Mock(
          'LocalHive',
          [
            _Block(_B.row,
                icon: _aIcon,
                color: LhColors.green,
                title: 'Review tab',
                subtitle: '3 applications awaiting your review'),
          ],
          highlight: 0)),
  const _Step(
      _adm,
      LhColors.green,
      _aIcon,
      'Step 37 — Check their details',
      'Each application shows the business name, category, city, availability '
          'window, and the applicant\'s email and phone — everything you need '
          'to verify them.',
      _Mock(
          'Provider Applications',
          [
            _Block(_B.row,
                icon: _oIcon,
                color: LhColors.indigo,
                title: 'Chennai Cash & Carry',
                subtitle: 'Indian store · Parsippany, NJ · 9 AM – 8 PM',
                trailing: 'Awaiting'),
            _Block(_B.row,
                icon: _cIcon,
                color: LhColors.navy,
                title: 'owner@chennai.example',
                subtitle: '+1 732 555 0456'),
          ],
          highlight: 0)),
  const _Step(
      _adm,
      LhColors.green,
      _aIcon,
      'Step 38 — Approve or decline',
      'Tap Approve and their listing goes live immediately with a '
          'congratulations text. Or Decline with a clear reason, which is sent '
          'to them so they can fix it and reapply.',
      _Mock(
          'Provider Applications',
          [
            _Block(_B.row,
                icon: _oIcon,
                color: LhColors.indigo,
                title: 'Chennai Cash & Carry',
                subtitle: 'Indian store · Parsippany, NJ',
                trailing: 'Awaiting'),
            _Block(_B.button, title: 'Approve'),
          ],
          highlight: 1)),
  const _Step(
      _adm,
      LhColors.green,
      _aIcon,
      'That is LocalHive, end to end',
      'Customers book and order, businesses fulfil, partners deliver, and you '
          'approve who joins — with a text message at every step and a flat '
          'twelve percent that keeps the platform running. Tap below to start '
          'using the app.',
      _Mock('LocalHive', [
        _Block(_B.row,
            icon: CupertinoIcons.checkmark_seal_fill,
            color: LhColors.blue,
            title: 'Verified providers',
            subtitle: 'ID-verified; home-service pros background-checked'),
        _Block(_B.row,
            icon: CupertinoIcons.lock_fill,
            color: LhColors.green,
            title: 'Protected payments',
            subtitle: 'Held securely until the job is done'),
        _Block(_B.row,
            icon: CupertinoIcons.percent,
            color: LhColors.navy,
            title: 'Transparent pricing',
            subtitle: 'Flat 12% fee, always shown before you pay'),
      ])),
];

class DemoTourScreen extends StatefulWidget {
  const DemoTourScreen({super.key});

  @override
  State<DemoTourScreen> createState() => _DemoTourScreenState();
}

class _DemoTourScreenState extends State<DemoTourScreen>
    with SingleTickerProviderStateMixin {
  int _i = 0;
  bool _sound = true;
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  // The shared engine rather than flutter_tts directly: on the web the plugin
  // goes silently mute (it reuses one utterance object, which Chrome drops
  // after any cancel), and the engine also picks Olivia's voice, so the tour
  // and the assistant sound like the same person.
  final SpeechEngine _tts = SpeechEngine();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  Future<void> _speak() async {
    if (!_sound) return;
    try {
      await _tts.speak(_steps[_i].narration);
    } catch (_) {
      // Narration is a bonus; the tour reads fine silently.
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _tts.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = _i + delta;
    if (next < 0) return;
    if (next >= _steps.length) {
      Navigator.pop(context);
      return;
    }
    setState(() => _i = next);
    _speak();
  }

  /// Jump to the first step of a persona so people can watch just their part.
  void _jumpToPersona(String persona) {
    final idx = _steps.indexWhere((s) => s.persona == persona);
    if (idx >= 0) {
      setState(() => _i = idx);
      _speak();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _steps[_i];
    const personas = [_cust, _own, _del, _adm];
    return Scaffold(
      backgroundColor: LhColors.background,
      appBar: AppBar(
        title: const Text('How LocalHive works'),
        actions: [
          IconButton(
            tooltip: _sound ? 'Mute narration' : 'Unmute narration',
            icon: Icon(
                _sound
                    ? CupertinoIcons.speaker_2_fill
                    : CupertinoIcons.speaker_slash_fill,
                size: 20),
            onPressed: () {
              setState(() => _sound = !_sound);
              if (_sound) {
                _speak();
              } else {
                _tts.stop();
              }
            },
          ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip')),
        ],
      ),
      body: Column(
        children: [
          // Persona chips — jump straight to the role you care about.
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final p in personas)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: ChoiceChip(
                      label: Text(p, style: const TextStyle(fontSize: 12)),
                      selected: s.persona == p,
                      onSelected: (_) => _jumpToPersona(p),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Row(
              children: [
                Icon(s.personaIcon, size: 14, color: s.color),
                const SizedBox(width: 6),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_i + 1) / _steps.length,
                    minHeight: 4,
                    backgroundColor: LhColors.hairline,
                    valueColor: AlwaysStoppedAnimation(s.color),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${_i + 1}/${_steps.length}',
                    style: const TextStyle(
                        fontSize: 12, color: LhColors.inkSecondary)),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _MockPhone(mock: s.mock, pulse: _pulse, accent: s.color),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: LhColors.surface,
                border: Border(top: BorderSide(color: LhColors.hairline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title,
                      style: const TextStyle(
                          fontSize: 16.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(s.narration,
                      style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: LhColors.inkSecondary)),
                  if (_i == _steps.length - 1) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SystemCheckScreen())),
                      icon:
                          const Icon(CupertinoIcons.checkmark_shield, size: 16),
                      label: const Text('Run a live system check'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42)),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (_i > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _go(-1),
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46)),
                            child: const Text('Back'),
                          ),
                        ),
                      if (_i > 0) const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () => _go(1),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(46)),
                          child: Text(_i == _steps.length - 1
                              ? 'Start using LocalHive'
                              : 'Next'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockPhone extends StatelessWidget {
  final _Mock mock;
  final Animation<double> pulse;
  final Color accent;
  const _MockPhone(
      {required this.mock, required this.pulse, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 330,
      decoration: BoxDecoration(
        color: LhColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: LhColors.hairline, width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(mock.appBar,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (var i = 0; i < mock.blocks.length; i++) ...[
            _spot(i == mock.highlight, _build(mock.blocks[i])),
            const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }

  Widget _build(_Block b) => switch (b.type) {
        _B.row => _card(Row(children: [
            IconTile(
                icon: b.icon ?? CupertinoIcons.circle,
                color: b.color ?? LhColors.navy,
                size: 32),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.title ?? '',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  if (b.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(b.subtitle!,
                        style: const TextStyle(
                            fontSize: 11, color: LhColors.inkSecondary)),
                  ],
                ],
              ),
            ),
            if (b.trailing != null)
              Text(b.trailing!,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
          ])),
        _B.banner => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: LhColors.navy, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: LhColors.orange,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('2',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(b.title ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        _B.button => Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: LhColors.navy, borderRadius: BorderRadius.circular(12)),
            child: Text(b.title ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
          ),
        _B.chips => Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < (b.options?.length ?? 0); i++)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: i == b.selected ? LhColors.navy : LhColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LhColors.hairline),
                  ),
                  child: Text(b.options![i],
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color:
                              i == b.selected ? Colors.white : LhColors.ink)),
                ),
            ],
          ),
        _B.field => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
                color: const Color(0xFFEBEBED),
                borderRadius: BorderRadius.circular(10)),
            child: Text(b.title ?? '',
                style: const TextStyle(
                    fontSize: 12, color: LhColors.inkSecondary)),
          ),
        _B.segments => Row(
            children: [
              for (var i = 0; i < (b.options?.length ?? 0); i++)
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i == 0 ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == b.selected ? LhColors.blue : LhColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: LhColors.hairline),
                    ),
                    child: Text(b.options![i],
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color:
                                i == b.selected ? Colors.white : LhColors.ink)),
                  ),
                ),
            ],
          ),
        _B.sms => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F8EC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(14),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: LhColors.green.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(CupertinoIcons.chat_bubble_fill,
                      size: 12, color: LhColors.green),
                  const SizedBox(width: 5),
                  Text(b.title ?? 'Message',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: LhColors.green)),
                ]),
                const SizedBox(height: 5),
                Text(b.subtitle ?? '',
                    style: const TextStyle(fontSize: 11.5, height: 1.35)),
              ],
            ),
          ),
        _B.otp => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final d in (b.title ?? '').split(' '))
                Container(
                  width: 42,
                  height: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: LhColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: LhColors.navy, width: 1.5),
                  ),
                  child: Text(d,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        _B.note => Text((b.title ?? '').toUpperCase(),
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: LhColors.inkSecondary)),
        _B.map => Container(
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFFDDE7DA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LhColors.hairline),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.location_solid,
                    size: 30, color: Color(0xFFFF3B30)),
                const SizedBox(height: 4),
                Text(b.title ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      };

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: LhColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LhColors.hairline, width: 0.5),
        ),
        child: child,
      );

  /// Dim everything except the element being explained; ring and point at it.
  Widget _spot(bool target, Widget child) {
    if (!target) return Opacity(opacity: 0.42, child: child);
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: accent.withValues(alpha: 0.30 * (1 - t) + 0.10),
                      blurRadius: 6 + 16 * t,
                      spreadRadius: 1 + 4 * t),
                ],
                border: Border.all(color: accent, width: 2.5),
              ),
              child: child,
            ),
            Positioned(
              right: -6,
              bottom: -10,
              child: Transform.translate(
                offset: Offset(0, -4 * t),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: accent, borderRadius: BorderRadius.circular(12)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(CupertinoIcons.hand_point_left_fill,
                        size: 13, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Tap here',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
