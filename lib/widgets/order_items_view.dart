import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/data.dart';
import '../theme.dart';

/// What was ordered, itemised.
///
/// Three people need this and each needs it slightly differently, so it is one
/// widget with an [audience] rather than three drifting copies:
///
/// * the business packing the order needs quantities to be unmissable;
/// * the customer needs prices, to check they were charged what they agreed;
/// * the courier needs the count, to know whether they have everything, and has
///   no business seeing what anyone paid.
///
/// Home-service bookings have no items — they are hours of someone's time — and
/// orders placed before contents were recorded have none either. Both cases
/// render nothing rather than an empty box.
enum OrderAudience {
  /// The store or truck owner: what to prepare.
  business,

  /// The customer who placed it: what they bought and what it cost.
  customer,

  /// The delivery partner: what they are carrying. No prices.
  courier,
}

class OrderItemsView extends StatelessWidget {
  final Booking booking;
  final OrderAudience audience;

  /// Collapses to a tappable summary when there are more lines than this. Long
  /// grocery orders otherwise push everything else off the card.
  final int collapseAbove;

  const OrderItemsView({
    super.key,
    required this.booking,
    required this.audience,
    this.collapseAbove = 4,
  });

  bool get _showPrices => audience != OrderAudience.courier;

  String get _heading => switch (audience) {
        OrderAudience.business => 'ORDER TO PREPARE',
        OrderAudience.customer => 'WHAT YOU ORDERED',
        OrderAudience.courier => 'WHAT YOU ARE CARRYING',
      };

  @override
  Widget build(BuildContext context) {
    final items = booking.items;
    if (items.isEmpty) return const SizedBox.shrink();

    final lines = <Widget>[
      for (final line in items) _Line(line: line, showPrice: _showPrices),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: LhColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LhColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  audience == OrderAudience.courier
                      ? CupertinoIcons.cube_box_fill
                      : CupertinoIcons.list_bullet,
                  size: 13,
                  color: LhColors.inkSecondary),
              const SizedBox(width: 6),
              Text(_heading,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: LhColors.inkSecondary)),
              const Spacer(),
              Text(
                  '${booking.itemCount} item${booking.itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 11.5, color: LhColors.inkSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          if (items.length > collapseAbove)
            _Expandable(lines: lines, visible: collapseAbove)
          else
            ...lines,
          if (_showPrices) ...[
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
            _Total(booking: booking, audience: audience),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final OrderLine line;
  final bool showPrice;
  const _Line({required this.line, required this.showPrice});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The quantity is the thing that gets misread when someone is packing
          // in a hurry, so it is boxed and bold rather than run into the name.
          Container(
            width: 30,
            padding: const EdgeInsets.symmetric(vertical: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: LhColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${line.qty}×',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: LhColors.navy)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${line.emoji.isEmpty ? '' : '${line.emoji} '}${line.name}',
                    style: const TextStyle(fontSize: 14.5)),
                if (showPrice && line.qty > 1)
                  Text(
                      '\$${line.unitPrice.toStringAsFixed(2)}'
                      '${line.unit.isEmpty ? '' : ' / ${line.unit}'} each',
                      style: const TextStyle(
                          fontSize: 11.5, color: LhColors.inkSecondary))
                else if (line.unit.isNotEmpty)
                  Text(line.unit,
                      style: const TextStyle(
                          fontSize: 11.5, color: LhColors.inkSecondary)),
              ],
            ),
          ),
          if (showPrice) ...[
            const SizedBox(width: 8),
            Text('\$${line.lineTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

/// The money, spelled out differently for the two people who care about it.
class _Total extends StatelessWidget {
  final Booking booking;
  final OrderAudience audience;
  const _Total({required this.booking, required this.audience});

  @override
  Widget build(BuildContext context) {
    final subtotal = booking.itemsSubtotal;
    // What the customer pays beyond the goods: the platform fee, and delivery
    // if it applies. Derived from the recorded total rather than recomputed, so
    // it always reconciles with what was actually charged.
    final extras = booking.amount - subtotal;

    return Column(
      children: [
        _row('Items', '\$${subtotal.toStringAsFixed(2)}'),
        if (extras.abs() >= 0.01)
          _row(
              audience == OrderAudience.business
                  ? 'Platform fee & delivery'
                  : 'Fees & delivery',
              '\$${extras.toStringAsFixed(2)}'),
        const SizedBox(height: 6),
        if (audience == OrderAudience.business)
          _row(
              'Customer pays on ${booking.fulfillment == 'delivery' ? 'delivery' : 'pickup'}',
              '\$${booking.amount.toStringAsFixed(2)}',
              bold: true)
        else
          _row('Total to pay in person',
              '\$${booking.amount.toStringAsFixed(2)}',
              bold: true),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: bold ? 14.5 : 13,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                      color: bold ? LhColors.ink : LhColors.inkSecondary)),
            ),
            Text(value,
                style: TextStyle(
                    fontSize: bold ? 14.5 : 13,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      );
}

/// Shows the first few lines with a tap to see the rest.
class _Expandable extends StatefulWidget {
  final List<Widget> lines;
  final int visible;
  const _Expandable({required this.lines, required this.visible});

  @override
  State<_Expandable> createState() => _ExpandableState();
}

class _ExpandableState extends State<_Expandable> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final hidden = widget.lines.length - widget.visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...(_open ? widget.lines : widget.lines.take(widget.visible)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(_open ? 'Show less' : 'Show all $hidden more',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: LhColors.blue)),
                const SizedBox(width: 4),
                Icon(
                    _open
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 12,
                    color: LhColors.blue),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
