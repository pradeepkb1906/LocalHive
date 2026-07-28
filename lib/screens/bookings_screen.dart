import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme.dart';

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
              Text('Bookings',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700, letterSpacing: -0.5)),
              const SizedBox(height: 20),
              if (bookings.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(CupertinoIcons.doc_text, size: 44, color: LhColors.hairline),
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
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                          subtitle: Text(bookings[i].detail,
                              style: const TextStyle(
                                  fontSize: 13, color: LhColors.inkSecondary)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('\$${bookings[i].amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(bookings[i].status,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: bookings[i].status == 'Confirmed'
                                          ? LhColors.green
                                          : LhColors.orange)),
                            ],
                          ),
                        ),
                        if (i != bookings.length - 1)
                          const Padding(
                              padding: EdgeInsets.only(left: 68), child: Divider()),
                      ]
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              const Center(
                child: Text('Live status updates arrive with real-time sync.',
                    style: TextStyle(color: LhColors.inkSecondary, fontSize: 12.5)),
              ),
            ],
          );
        },
      ),
    );
  }
}
