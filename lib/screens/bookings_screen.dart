import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/location_chip.dart';
import 'track_delivery_screen.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final bookings = AppState.instance.bookings;
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
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < bookings.length; i++) ...[
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          leading: IconTile(
                              icon: bookings[i].status == 'Confirmed'
                                  ? CupertinoIcons.calendar_badge_plus
                                  : CupertinoIcons.bag_fill,
                              color: bookings[i].status == 'Confirmed'
                                  ? LhColors.indigo
                                  : LhColors.orange,
                              size: 36),
                          title: Text(bookings[i].providerName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(bookings[i].detail,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: LhColors.inkSecondary)),
                              if (bookings[i].otp.isNotEmpty &&
                                  bookings[i].status != 'Delivered')
                                Text(
                                    'Delivery OTP: ${bookings[i].otp} — share on arrival',
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
                              Text('\$${bookings[i].amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(bookings[i].status,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: switch (bookings[i].status) {
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
                        // A delivery order becomes trackable the moment a
                        // partner is on it.
                        if (bookings[i].fulfillment == 'delivery' &&
                            const ['Ready', 'Out for delivery']
                                .contains(bookings[i].status) &&
                            bookings[i].id.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, bottom: 10),
                            child: Row(
                              children: [
                                const Icon(CupertinoIcons.map_pin_ellipse,
                                    size: 15, color: LhColors.blue),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                      'Watch your delivery partner approach in '
                                      'real time.',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: LhColors.inkSecondary)),
                                ),
                                SizedBox(
                                  height: 32,
                                  child: FilledButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TrackDeliveryScreen(
                                          jobId: bookings[i].id,
                                          title: bookings[i].providerName,
                                          dropAddress: bookings[i].address,
                                        ),
                                      ),
                                    ),
                                    style: compactButtonStyle(
                                        width: 74, height: 32),
                                    child: const Text('Track'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (i != bookings.length - 1)
                          const Padding(
                              padding: EdgeInsets.only(left: 68),
                              child: Divider()),
                      ]
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              const Center(
                child: Text('Live status updates arrive with real-time sync.',
                    style: TextStyle(
                        color: LhColors.inkSecondary, fontSize: 12.5)),
              ),
            ],
          );
        },
      ),
    );
  }
}
