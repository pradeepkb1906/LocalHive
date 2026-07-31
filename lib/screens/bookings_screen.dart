import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/data.dart';
import '../theme.dart';
import '../widgets/location_chip.dart';
import '../widgets/order_items_view.dart';
import 'track_delivery_screen.dart';

/// The customer's orders and bookings: everything still moving first, then
/// history — each newest first, each stamped with when it was placed. The
/// shape every ordering app converges on, because it answers the two
/// questions people open this screen with: "where is my order?" and
/// "what did I order last time?".
class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final bookings = AppState.instance.bookings;
          final active = bookings.where((b) => b.isActive).toList();
          final past = bookings.where((b) => !b.isActive).toList();
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              Row(
                children: [
                  Text('Bookings',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5)),
                  const Spacer(),
                  const LocationChip(),
                ],
              ),
              const SizedBox(height: 20),
              if (bookings.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(CupertinoIcons.doc_text,
                            size: 44, color: LhColors.hairline),
                        SizedBox(height: 12),
                        Text('No bookings yet',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text('Book a service or place an order to see it here.',
                            style: TextStyle(
                                fontSize: 13, color: LhColors.inkSecondary)),
                      ],
                    ),
                  ),
                )
              else ...[
                // The stream arrives newest first; partitioning preserves
                // that, so each section is newest first too.
                if (active.isNotEmpty) ...[
                  _sectionLabel('In progress'),
                  _group(context, active),
                  const SizedBox(height: 18),
                ],
                if (past.isNotEmpty) ...[
                  _sectionLabel('Past'),
                  _group(context, past),
                ],
                const SizedBox(height: 20),
                const Center(
                  child: Text('Live status updates arrive with real-time sync.',
                      style: TextStyle(
                          color: LhColors.inkSecondary, fontSize: 12.5)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: LhColors.inkSecondary)),
      );

  Widget _group(BuildContext context, List<Booking> bookings) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < bookings.length; i++) ...[
            _row(context, bookings[i]),
            if (i != bookings.length - 1)
              const Padding(
                  padding: EdgeInsets.only(left: 68), child: Divider()),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Booking b) {
    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: IconTile(
              icon: b.status == 'Confirmed'
                  ? CupertinoIcons.calendar_badge_plus
                  : CupertinoIcons.bag_fill,
              color:
                  b.status == 'Confirmed' ? LhColors.indigo : LhColors.orange,
              size: 36),
          title: Text(b.providerName,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.detail,
                  style: const TextStyle(
                      fontSize: 13, color: LhColors.inkSecondary)),
              // When it was placed — the thing this screen exists to answer.
              if (b.placedLabel.isNotEmpty)
                Text(b.placedLabel,
                    style: const TextStyle(
                        fontSize: 12, color: LhColors.inkSecondary)),
              if (b.otp.isNotEmpty && b.status != 'Delivered')
                Text('Delivery OTP: ${b.otp} — share on arrival',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: LhColors.navy)),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${b.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(b.status,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: switch (b.status) {
                        'Completed' ||
                        'Delivered' ||
                        'Confirmed' =>
                          LhColors.green,
                        'Accepted' ||
                        'Preparing' ||
                        'Ready' ||
                        'Out for delivery' =>
                          LhColors.blue,
                        'Declined' => const Color(0xFFFF3B30),
                        _ => LhColors.orange,
                      })),
            ],
          ),
        ),
        // What they actually ordered. Under the row rather than inside it: a
        // ListTile subtitle has no room for a list, and this is the thing
        // people open Bookings to check.
        if (b.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: OrderItemsView(booking: b, audience: OrderAudience.customer),
          ),
        // A delivery order becomes trackable the moment a partner is on it.
        if (b.fulfillment == 'delivery' &&
            const ['Ready', 'Out for delivery'].contains(b.status) &&
            b.id.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
            child: Row(
              children: [
                const Icon(CupertinoIcons.map_pin_ellipse,
                    size: 15, color: LhColors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                      'Watch your delivery partner approach in real time.',
                      style: TextStyle(
                          fontSize: 12.5, color: LhColors.inkSecondary)),
                ),
                SizedBox(
                  height: 32,
                  child: FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrackDeliveryScreen(
                          jobId: b.id,
                          title: b.providerName,
                          dropAddress: b.address,
                        ),
                      ),
                    ),
                    style: compactButtonStyle(width: 74, height: 32),
                    child: const Text('Track'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
