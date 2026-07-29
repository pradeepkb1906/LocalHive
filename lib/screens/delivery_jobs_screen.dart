import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/data.dart';
import '../services/firebase_service.dart';
import '../theme.dart';

/// Delivery-partner interface: open jobs from stores/trucks to claim, then
/// Picked Up → Delivered. Each step notifies the customer (SMS/WhatsApp).
class DeliveryJobsScreen extends StatelessWidget {
  const DeliveryJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppState.instance.signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Jobs')),
        body: const Center(
            child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Sign in to see and claim delivery jobs.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: LhColors.inkSecondary)),
        )),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Jobs')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService.instance.deliveryJobsStream(),
        builder: (context, snap) {
          final jobs = snap.data ?? const [];
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
                    Icon(CupertinoIcons.cube_box, size: 44, color: LhColors.hairline),
                    SizedBox(height: 12),
                    Text('No delivery jobs right now',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text(
                        'When a store marks a delivery order Ready, it appears '
                        'here for any partner to claim.',
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
            itemBuilder: (context, i) => _DeliveryCard(job: jobs[i]),
          );
        },
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final Map<String, dynamic> job;
  const _DeliveryCard({required this.job});

  Future<void> _act(BuildContext context) async {
    final fb = FirebaseService.instance;
    final id = job['id'] as String;
    final status = job['status'] as String;
    final notify = Booking(
      (job['storeName'] ?? '') as String,
      (job['orderDetail'] ?? '') as String,
      status,
      0,
      id: id,
      address: (job['dropAddress'] ?? '') as String,
      customerPhone: (job['customerPhone'] ?? '') as String,
      customerEmail: (job['customerEmail'] ?? '') as String,
    );
    String msg;
    if (status == 'Open') {
      await fb.claimDeliveryJob(id);
      msg = 'Job claimed — head to ${job['storeName']} for pickup.';
    } else if (status == 'Claimed') {
      await fb.advanceDeliveryJob(id, 'PickedUp', notify);
      msg = 'Picked up — customer notified you are on the way.';
    } else {
      await fb.advanceDeliveryJob(id, 'Delivered', notify);
      msg = 'Delivered! Your \$${((job['fee'] ?? 0) as num).toStringAsFixed(2)} '
          'delivery fee is queued for payout.';
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = job['status'] as String;
    final mine = status != 'Open';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${job['storeName']}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Text('\$${((job['fee'] ?? 0) as num).toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: LhColors.green)),
              ],
            ),
            const SizedBox(height: 6),
            Text('${job['orderDetail']}',
                style: const TextStyle(fontSize: 13.5, color: LhColors.inkSecondary)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(CupertinoIcons.location_solid,
                    size: 14, color: LhColors.inkSecondary),
                const SizedBox(width: 6),
                Expanded(
                    child: Text('Deliver to: ${job['dropAddress']}',
                        style: const TextStyle(fontSize: 13.5))),
              ],
            ),
            if (mine && (job['customerPhone'] ?? '') != '') ...[
              const SizedBox(height: 4),
              Text('Customer: ${job['customerPhone']}',
                  style: const TextStyle(fontSize: 13, color: LhColors.inkSecondary)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _act(context),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  backgroundColor: status == 'Open' ? LhColors.blue : LhColors.navy),
              child: Text(switch (status) {
                'Open' => 'Claim This Delivery',
                'Claimed' => 'Mark Picked Up',
                _ => 'Mark Delivered',
              }),
            ),
          ],
        ),
      ),
    );
  }
}
