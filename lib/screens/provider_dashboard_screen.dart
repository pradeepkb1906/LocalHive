import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/data.dart';
import '../services/firebase_service.dart';
import '../theme.dart';

/// Provider-side interface: incoming job requests with Accept / Decline,
/// then Mark Complete. Every action queues SMS + email notifications for
/// the customer via the notifications outbox. Scoped by security rules to
/// bookings whose listing is owned by the signed-in user.
class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Provider Dashboard')),
      body: StreamBuilder<List<Booking>>(
        stream: FirebaseService.instance.providerJobsStream(),
        builder: (context, snap) {
          final jobs = snap.data ?? const <Booking>[];
          if (!snap.hasData && !snap.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (jobs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.tray, size: 44, color: LhColors.hairline),
                    SizedBox(height: 12),
                    Text('No job requests yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text(
                        'Sign in and get your listing approved — bookings for '
                        'your listings appear here, and you are notified by '
                        'SMS and email.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: LhColors.inkSecondary)),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _JobCard(job: jobs[i]),
          );
        },
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Booking job;
  const _JobCard({required this.job});

  Color get _statusColor => switch (job.status) {
        'Requested' || 'Placed' => LhColors.orange,
        'Accepted' || 'Preparing' || 'Ready' || 'Out for delivery' => LhColors.blue,
        'Completed' || 'Delivered' => LhColors.green,
        'Declined' => const Color(0xFFFF3B30),
        _ => LhColors.inkSecondary,
      };

  Future<void> _update(BuildContext context, String status) async {
    await FirebaseService.instance.updateBookingStatus(job, status);
    if (status == 'Ready' && job.fulfillment == 'delivery') {
      await FirebaseService.instance.createDeliveryJob(job);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(switch (status) {
        'Accepted' =>
          'Job accepted — the customer has been notified.',
        'Declined' => 'Job declined — the customer has been notified.',
        'Preparing' => 'Order accepted — customer notified you are preparing it.',
        'Ready' => job.fulfillment == 'delivery'
            ? 'Marked ready — posted to the delivery job board, customer notified.'
            : 'Marked ready — customer notified to come pick it up.',
        _ => 'Completed — receipt sent to customer, payout queued.',
      })));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(job.detail,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(job.status,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _row(CupertinoIcons.location_solid,
                job.address.isEmpty ? 'No address given' : job.address),
            const SizedBox(height: 6),
            _row(CupertinoIcons.person_fill,
                '${job.customerName.isEmpty ? 'Customer' : job.customerName}'
                '${job.customerPhone.isEmpty ? '' : ' · ${job.customerPhone}'}'),
            const SizedBox(height: 6),
            _row(CupertinoIcons.money_dollar_circle_fill,
                'You earn \$${(job.amount / (1 + platformFeePct)).toStringAsFixed(2)} '
                '(customer pays \$${job.amount.toStringAsFixed(2)})'),
            if (job.status == 'Requested') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _update(context, 'Accepted'),
                      style: FilledButton.styleFrom(
                          backgroundColor: LhColors.green,
                          minimumSize: const Size.fromHeight(42)),
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _update(context, 'Declined'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF3B30),
                          minimumSize: const Size.fromHeight(42)),
                      child: const Text('Decline'),
                    ),
                  ),
                ],
              ),
            ] else if (job.status == 'Accepted') ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => _update(context, 'Completed'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                child: const Text('Mark Job Complete'),
              ),
            ] else if (job.status == 'Placed') ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => _update(context, 'Preparing'),
                style: FilledButton.styleFrom(
                    backgroundColor: LhColors.green,
                    minimumSize: const Size.fromHeight(42)),
                child: const Text('Accept Order & Start Preparing'),
              ),
            ] else if (job.status == 'Preparing') ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => _update(context, 'Ready'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                child: Text(job.fulfillment == 'delivery'
                    ? 'Mark Ready & Request Delivery Partner'
                    : 'Mark Ready for Pickup'),
              ),
            ] else if (job.status == 'Ready' && job.fulfillment != 'delivery') ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => _update(context, 'Completed'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                child: const Text('Customer Picked Up — Complete'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: LhColors.inkSecondary),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13.5, color: LhColors.ink))),
      ],
    );
  }
}
