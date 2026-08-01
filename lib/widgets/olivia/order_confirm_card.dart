import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../services/olivia/order_draft.dart';
import '../../theme.dart';

/// Shows what Olivia has worked out, itemised, and puts the decision in the
/// customer's hands.
///
/// This is the only path in the app by which Olivia's conversation becomes a
/// real booking. Everything the language model did up to here was a proposal.
class OrderConfirmCard extends StatelessWidget {
  final OrderDraft draft;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const OrderConfirmCard({
    super.key,
    required this.draft,
    required this.onConfirm,
    required this.onCancel,
    this.busy = false,
  });

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: bold ? 15 : 13.5,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                      color: bold ? LhColors.ink : LhColors.inkSecondary)),
            ),
            Text(value,
                style: TextStyle(
                    fontSize: bold ? 16 : 13.5,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: LhColors.ink)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      color: LhColors.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LhColors.blue.withValues(alpha: 0.35)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconTile(
                    icon: CupertinoIcons.bag_fill,
                    color: LhColors.green,
                    size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Confirm this order',
                          style: TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w700)),
                      Text(draft.providerName,
                          style: const TextStyle(
                              fontSize: 13, color: LhColors.inkSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final line in draft.lines)
              _row('${line.qty} × ${line.name}',
                  '\$${line.lineTotal.toStringAsFixed(2)}'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            _row('Subtotal', '\$${draft.subtotal.toStringAsFixed(2)}'),
            _row('Platform fee (12%)',
                '\$${draft.platformFee.toStringAsFixed(2)}'),
            if (draft.deliveryCharge > 0)
              _row('Delivery', '\$${draft.deliveryCharge.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            _row('Total', '\$${draft.total.toStringAsFixed(2)}', bold: true),
            const SizedBox(height: 10),
            if (draft.isDelivery && draft.address.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(CupertinoIcons.location_solid,
                      size: 14, color: LhColors.inkSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Deliver to ${draft.address}',
                        style: const TextStyle(
                            fontSize: 12.5, color: LhColors.inkSecondary)),
                  ),
                ],
              ),
            if (!draft.isDelivery && draft.pickupEta.isNotEmpty)
              Row(
                children: [
                  const Icon(CupertinoIcons.time,
                      size: 14, color: LhColors.inkSecondary),
                  const SizedBox(width: 6),
                  Text('You arrive ${draft.pickupEta.toLowerCase()}',
                      style: const TextStyle(
                          fontSize: 12.5, color: LhColors.inkSecondary)),
                ],
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: LhColors.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.money_dollar_circle,
                      size: 16, color: LhColors.green),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                        'You pay the business directly when you collect or '
                        'when it arrives. Nothing is charged in the app.',
                        style: TextStyle(
                            fontSize: 12, color: LhColors.inkSecondary)),
                  ),
                ],
              ),
            ),
            if (!draft.isReady) ...[
              const SizedBox(height: 10),
              for (final blocker in draft.blockers)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                        size: 14, color: LhColors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(blocker,
                          style: const TextStyle(
                              fontSize: 12.5, color: LhColors.orange)),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        foregroundColor: LhColors.inkSecondary),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: (busy || !draft.isReady) ? null : onConfirm,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        backgroundColor: LhColors.green),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Place order · '
                            '\$${draft.total.toStringAsFixed(2)}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
