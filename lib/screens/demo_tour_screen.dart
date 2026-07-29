import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../theme.dart';

/// One row inside the mock phone screen.
class _Row {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? trailing;
  const _Row(this.icon, this.color, this.title, this.subtitle, [this.trailing]);
}

/// What the mock phone shows for a step, and which element to spotlight.
class _Mock {
  final String appBar;
  final String? banner;
  final List<_Row> rows;
  final String? button;
  /// 'banner' | 'row0'..'rowN' | 'button' | 'tab'
  final String highlight;
  const _Mock({
    required this.appBar,
    this.banner,
    this.rows = const [],
    this.button,
    required this.highlight,
  });
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

const _steps = <_Step>[
  // ---------------- Customer ----------------
  _Step(
      'Customer',
      LhColors.blue,
      CupertinoIcons.person_fill,
      'Find what you need',
      'Welcome to LocalHive. As a customer, you start here. Tap Home Services '
          'to find a cleaner or handyman, Indian Stores for groceries, or Food '
          'Trucks to order ahead.',
      _Mock(
        appBar: 'LocalHive',
        rows: [
          _Row(CupertinoIcons.sparkles, LhColors.indigo, 'Home Services',
              'Cleaners & handymen, background-checked'),
          _Row(CupertinoIcons.cart_fill, LhColors.green, 'Indian Stores',
              'Groceries & essentials, pickup or delivery'),
          _Row(CupertinoIcons.car_detailed, LhColors.orange, 'Food Trucks',
              'Live locations, skip the line'),
        ],
        highlight: 'row0',
      )),
  _Step(
      'Customer',
      LhColors.blue,
      CupertinoIcons.person_fill,
      'Pick a verified pro',
      'Every provider is ID-verified, and home-service pros are background '
          'checked. You can see their rating, hourly rate, and the hours they '
          'are available. Tap Maria to book her.',
      _Mock(
        appBar: 'Home Services',
        rows: [
          _Row(CupertinoIcons.person_fill, LhColors.indigo, 'Maria G. ✓',
              '⭐ 4.9 (212) · Available 8 AM – 6 PM', '\$28/hr'),
          _Row(CupertinoIcons.person_fill, LhColors.indigo, 'Dave R. ✓',
              '⭐ 4.8 (158) · Handyman', '\$45/hr'),
        ],
        highlight: 'row0',
      )),
  _Step(
      'Customer',
      LhColors.blue,
      CupertinoIcons.person_fill,
      'Book in seconds',
      'Choose the day, start time, and how many hours. Add the address where '
          'the pro should come. The twelve percent platform fee is always shown '
          'before you pay, and you are only charged after the job is done. '
          'Tap Book.',
      _Mock(
        appBar: 'Maria G.',
        rows: [
          _Row(CupertinoIcons.calendar, LhColors.navy, 'Tomorrow · 10:00 AM',
              '3 hours'),
          _Row(CupertinoIcons.location_solid, LhColors.navy, 'Service address',
              '45 Oak Tree Road, Edison, NJ'),
          _Row(CupertinoIcons.money_dollar_circle_fill, LhColors.navy, 'Total',
              '\$84 + 12% fee = \$94.08'),
        ],
        button: 'Book for \$94.08',
        highlight: 'button',
      )),
  _Step(
      'Customer',
      LhColors.blue,
      CupertinoIcons.person_fill,
      'Track it live',
      'Your booking appears in the Bookings tab. You get a text message at '
          'every step: when the provider accepts, when they are on the way, '
          'and when the job is complete.',
      _Mock(
        appBar: 'Bookings',
        rows: [
          _Row(CupertinoIcons.calendar_badge_plus, LhColors.indigo, 'Maria G.',
              'House cleaning · Tomorrow 10 AM', 'Accepted'),
        ],
        highlight: 'row0',
      )),
  // ---------------- Business owner ----------------
  _Step(
      'Business owner',
      LhColors.indigo,
      CupertinoIcons.briefcase_fill,
      'Your orders find you',
      'Now the business side. When a store owner, food truck, or home service '
          'provider signs in, LocalHive opens straight on their Dashboard, and '
          'this banner shows how many orders are waiting.',
      _Mock(
        appBar: 'LocalHive',
        banner: '2 orders waiting — tap to open your Dashboard',
        rows: [
          _Row(CupertinoIcons.sparkles, LhColors.indigo, 'Home Services',
              'Browse as a customer too'),
        ],
        highlight: 'banner',
      )),
  _Step(
      'Business owner',
      LhColors.indigo,
      CupertinoIcons.briefcase_fill,
      'Accept and fulfil',
      'Each card shows the customer, the address with a directions button, and '
          'exactly what you earn. Tap Accept, then move the order through '
          'Preparing, Ready, and Delivered. The customer is texted at every '
          'step automatically.',
      _Mock(
        appBar: 'Provider Dashboard',
        rows: [
          _Row(CupertinoIcons.doc_text_fill, LhColors.orange,
              'House cleaning · 3 hrs', 'You earn \$84.00', 'Requested'),
        ],
        button: 'Accept',
        highlight: 'button',
      )),
  _Step(
      'Business owner',
      LhColors.indigo,
      CupertinoIcons.briefcase_fill,
      'Food trucks: announce arrival',
      'If you run a food truck, tap the megaphone to announce that you have '
          'arrived. Every customer who followed your truck instantly gets a '
          'text telling them where you are parked.',
      _Mock(
        appBar: 'Provider Dashboard',
        rows: [
          _Row(CupertinoIcons.speaker_2_fill, LhColors.orange,
              'Announce arrival', '12 customers follow your truck'),
        ],
        button: 'Announce',
        highlight: 'button',
      )),
  // ---------------- Delivery partner ----------------
  _Step(
      'Delivery partner',
      LhColors.orange,
      CupertinoIcons.cube_box_fill,
      'Earn on your schedule',
      'Students and gig workers can register as delivery partners and set the '
          'hours they are free. Your board shows your active deliveries and '
          'every open job you can claim.',
      _Mock(
        appBar: 'Delivery Jobs',
        rows: [
          _Row(CupertinoIcons.cube_box_fill, LhColors.navy, 'My deliveries: 1',
              'Open to claim: 3'),
          _Row(CupertinoIcons.bag_fill, LhColors.orange, 'Patel Brothers',
              'Deliver to 456 Wood Ave · On your way!', '\$4.99'),
        ],
        highlight: 'row1',
      )),
  _Step(
      'Delivery partner',
      LhColors.orange,
      CupertinoIcons.cube_box_fill,
      'Claim, pick up, deliver',
      'Claim a job and the app shows directions to the store and then to the '
          'customer. Jobs that are already on your route are marked, so you '
          'can carry two orders in one trip.',
      _Mock(
        appBar: 'Delivery Jobs',
        rows: [
          _Row(CupertinoIcons.bag_fill, LhColors.orange, 'Bombay Street Eats',
              'Deliver to 456 Wood Ave, Iselin', '\$4.99'),
        ],
        button: 'Claim This Delivery',
        highlight: 'button',
      )),
  _Step(
      'Delivery partner',
      LhColors.orange,
      CupertinoIcons.cube_box_fill,
      'Finish with the customer OTP',
      'At the door, ask the customer for the four digit code from their order '
          'message. Enter it to complete the delivery. This proves the food '
          'reached the right person, and protects everyone.',
      _Mock(
        appBar: 'Confirm delivery',
        rows: [
          _Row(CupertinoIcons.lock_shield_fill, LhColors.navy,
              'Enter customer OTP', 'Four digit code from their order'),
        ],
        button: 'Confirm Delivery',
        highlight: 'button',
      )),
  // ---------------- Admin ----------------
  _Step(
      'Admin',
      LhColors.green,
      CupertinoIcons.checkmark_shield_fill,
      'You approve who joins',
      'Finally, the admin. Anyone applying to offer services, sell groceries, '
          'run a truck, or deliver lands in your Review tab, and the badge '
          'shows how many are waiting.',
      _Mock(
        appBar: 'LocalHive',
        rows: [
          _Row(CupertinoIcons.checkmark_shield_fill, LhColors.green,
              'Review tab', '3 applications awaiting your review'),
        ],
        highlight: 'row0',
      )),
  _Step(
      'Admin',
      LhColors.green,
      CupertinoIcons.checkmark_shield_fill,
      'Approve and they go live',
      'Check their details, then tap Approve. Their listing is published to '
          'the catalog immediately and they get a text with the good news. '
          'That is LocalHive, end to end. Enjoy!',
      _Mock(
        appBar: 'Provider Applications',
        rows: [
          _Row(CupertinoIcons.briefcase_fill, LhColors.indigo,
              'Chennai Cash & Carry', 'Indian store · Parsippany, NJ',
              'Awaiting'),
        ],
        button: 'Approve',
        highlight: 'button',
      )),
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
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _configureTts();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  Future<void> _configureTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
    } catch (_) {}
  }

  Future<void> _speak() async {
    if (!_sound) return;
    try {
      await _tts.stop();
      await _tts.speak(_steps[_i].narration);
    } catch (_) {
      // Narration is a bonus; the tour works fine silently.
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _tts.stop();
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

  @override
  Widget build(BuildContext context) {
    final s = _steps[_i];
    return Scaffold(
      backgroundColor: LhColors.background,
      appBar: AppBar(
        title: const Text('How LocalHive works'),
        actions: [
          IconButton(
            tooltip: _sound ? 'Mute narration' : 'Unmute narration',
            icon: Icon(
                _sound ? CupertinoIcons.speaker_2_fill : CupertinoIcons.speaker_slash_fill,
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
          // Persona + progress
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: s.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(s.personaIcon, size: 14, color: s.color),
                    const SizedBox(width: 5),
                    Text(s.persona,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: s.color)),
                  ]),
                ),
                const Spacer(),
                Text('${_i + 1} / ${_steps.length}',
                    style: const TextStyle(
                        fontSize: 12.5, color: LhColors.inkSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(
              value: (_i + 1) / _steps.length,
              minHeight: 4,
              backgroundColor: LhColors.hairline,
              valueColor: AlwaysStoppedAnimation(s.color),
            ),
          ),
          // Mock phone with spotlight
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _MockPhone(mock: s.mock, pulse: _pulse, accent: s.color),
              ),
            ),
          ),
          // Narration text + controls
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
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(s.narration,
                      style: const TextStyle(
                          fontSize: 14, height: 1.4,
                          color: LhColors.inkSecondary)),
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

/// Mock phone frame that dims everything except the highlighted element,
/// which gets a pulsing ring and a tap indicator.
class _MockPhone extends StatelessWidget {
  final _Mock mock;
  final Animation<double> pulse;
  final Color accent;
  const _MockPhone(
      {required this.mock, required this.pulse, required this.accent});

  bool _isTarget(String key) => mock.highlight == key;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
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
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(mock.appBar,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          if (mock.banner != null) ...[
            _spot(
              _isTarget('banner'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LhColors.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
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
                    child: Text(mock.banner!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (var i = 0; i < mock.rows.length; i++) ...[
            _spot(_isTarget('row$i'), _rowCard(mock.rows[i])),
            const SizedBox(height: 10),
          ],
          if (mock.button != null) ...[
            const SizedBox(height: 2),
            _spot(
              _isTarget('button'),
              Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LhColors.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(mock.button!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rowCard(_Row r) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LhColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LhColors.hairline, width: 0.5),
        ),
        child: Row(
          children: [
            IconTile(icon: r.icon, color: r.color, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(r.subtitle,
                      style: const TextStyle(
                          fontSize: 11.5, color: LhColors.inkSecondary)),
                ],
              ),
            ),
            if (r.trailing != null)
              Text(r.trailing!,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  /// Wraps a widget: dims it when it is not the target, or rings + points at
  /// it when it is.
  Widget _spot(bool target, Widget child) {
    if (!target) return Opacity(opacity: 0.45, child: child);
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
                    color: accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
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
