import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/data.dart';
import '../theme.dart';
import '../widgets/location_chip.dart';
import 'profile_screen.dart';

/// Books a home-service provider for a 3-4 hour visit with the transparent
/// fee breakdown. Confirming records a real booking in AppState.
class BookingScreen extends StatefulWidget {
  final Provider provider;
  const BookingScreen({super.key, required this.provider});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int _hours = 3;
  int _dayOffset = 1;
  String _slot = '10:00 AM';
  late final _name =
      TextEditingController(text: AppState.instance.userName ?? '');
  late final _phone =
      TextEditingController(text: AppState.instance.userPhone ?? '');
  late final _email =
      TextEditingController(text: AppState.instance.userEmail ?? '');
  final _address = TextEditingController();

  static const _slots = ['8:00 AM', '10:00 AM', '1:00 PM', '3:00 PM'];

  double get _subtotal => widget.provider.hourlyRate * _hours;
  double get _fee => _subtotal * platformFeePct;
  double get _total => money(_subtotal + _fee);

  String _dayLabel(int offset) {
    const names = ['Today', 'Tomorrow', 'In 2 days', 'In 3 days', 'In 4 days'];
    return names[offset];
  }

  void _confirm() {
    if (!AppState.instance.signedIn && AppState.instance.firebaseReady) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Please sign in to book — it keeps your booking secure.')));
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const SignInScreen()));
      return;
    }
    if (_address.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Enter the full service address (street, city, state).')));
      return;
    }
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Enter your name and phone so the provider can reach you.')));
      return;
    }
    AppState.instance.addBooking(Booking(
      widget.provider.name,
      '${widget.provider.subtitle.split(' · ').first} · ${_dayLabel(_dayOffset)} $_slot · $_hours hrs',
      'Requested',
      _total,
      providerId: widget.provider.id,
      category: 'home_service',
      address: _address.text.trim(),
      customerName: _name.text.trim(),
      customerPhone: _phone.text.trim(),
      customerEmail: _email.text.trim(),
    ));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(CupertinoIcons.paperplane_fill,
            color: LhColors.blue, size: 44),
        title: const Text('Request sent'),
        content: Text(
            '${widget.provider.name} · ${_dayLabel(_dayOffset)} at $_slot for $_hours hours.\n\n'
            '${widget.provider.name} has been notified and will accept shortly — '
            'you\'ll get an SMS and email the moment they do. Track it in the '
            'Bookings tab. You pay \$${_total.toStringAsFixed(2)} directly to '
            'them once the job is done — nothing is charged in the app.'),
        actions: [
          FilledButton(
            style: dialogButtonStyle(),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(s.toUpperCase(),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: LhColors.inkSecondary,
                letterSpacing: 0.3)),
      );

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    return Scaffold(
      appBar: AppBar(title: Text(p.name), actions: const [LocationChip()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: LhColors.indigo.withValues(alpha: 0.14),
                    child: Text(p.name.substring(0, 1),
                        style: const TextStyle(
                            color: LhColors.indigo,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(p.name,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 5),
                          const Icon(CupertinoIcons.checkmark_seal_fill,
                              size: 16, color: LhColors.blue),
                        ]),
                        const SizedBox(height: 2),
                        Text(p.subtitle,
                            style: const TextStyle(
                                fontSize: 13, color: LhColors.inkSecondary)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(CupertinoIcons.star_fill,
                              size: 13, color: LhColors.amber),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                                '${p.rating} (${p.reviews} reviews) · Background checked',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: LhColors.inkSecondary)),
                          ),
                        ]),
                        if (p.availability.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(CupertinoIcons.time,
                                size: 13, color: LhColors.green),
                            const SizedBox(width: 3),
                            Text('Available ${p.availability}',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: LhColors.green)),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel('Day'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              5,
              (i) => ChoiceChip(
                label: Text(_dayLabel(i)),
                selected: _dayOffset == i,
                onSelected: (_) => setState(() => _dayOffset = i),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('Start time'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _slots
                .map((s) => ChoiceChip(
                    label: Text(s),
                    selected: _slot == s,
                    onSelected: (_) => setState(() => _slot = s)))
                .toList(),
          ),
          const SizedBox(height: 20),
          _sectionLabel('Duration'),
          Wrap(
            spacing: 8,
            children: [3, 4]
                .map((h) => ChoiceChip(
                    label: Text('$h hours'),
                    selected: _hours == h,
                    onSelected: (_) => setState(() => _hours = h)))
                .toList(),
          ),
          const SizedBox(height: 24),
          _sectionLabel('Service address & contact'),
          TextField(
            controller: _address,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                hintText:
                    'Street address, city, state (where the pro should come)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Your name'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(hintText: 'Mobile (SMS updates)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(hintText: 'Email (receipts)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel('Summary'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('$_hours hrs × \$${p.hourlyRate.toStringAsFixed(0)}/hr',
                      '\$${_subtotal.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  _row('Platform fee (12%)', '\$${_fee.toStringAsFixed(2)}'),
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider()),
                  _row('Total', '\$${_total.toStringAsFixed(2)}', bold: true),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        '${p.name} receives \$${_subtotal.toStringAsFixed(2)}, paid out after completion.',
                        style: const TextStyle(
                            fontSize: 12.5, color: LhColors.inkSecondary)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _confirm,
            child: Text('Book for \$${_total.toStringAsFixed(2)}'),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('Free cancellation up to 24 hours before the visit.',
                style: TextStyle(fontSize: 12.5, color: LhColors.inkSecondary)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        fontSize: bold ? 17 : 14.5);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: style)),
        Text(value, style: style)
      ],
    );
  }
}
