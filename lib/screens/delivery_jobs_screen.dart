import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/data.dart';
import 'directions_screen.dart';
import 'track_delivery_screen.dart';
import '../services/courier_beacon.dart';
import '../services/firebase_service.dart';
import '../theme.dart';
import '../widgets/location_chip.dart';
import '../widgets/order_items_view.dart';

/// Delivery-partner interface: open jobs from stores/trucks to claim, then
/// Picked Up → Delivered. Each step notifies the customer (SMS/WhatsApp), and
/// while a job is active the partner's GPS position is shared so the customer
/// can watch them approach.
class DeliveryJobsScreen extends StatelessWidget {
  const DeliveryJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppState.instance.signedIn) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('Delivery Jobs'),
            actions: const [LocationChip()]),
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
      appBar: AppBar(
          title: const Text('Delivery Jobs'), actions: const [LocationChip()]),
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
                    Icon(CupertinoIcons.cube_box,
                        size: 44, color: LhColors.hairline),
                    SizedBox(height: 12),
                    Text('No delivery jobs right now',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text(
                        'When a store marks a delivery order Ready, it appears '
                        'here for any partner to claim.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: LhColors.inkSecondary)),
                  ],
                ),
              ),
            );
          }
          final mine = jobs.where((j) => j['status'] != 'Open').toList();
          final open = jobs.where((j) => j['status'] == 'Open').toList();
          // Share this partner's location for as long as they hold a job that
          // has not been delivered. Done after the frame so a stream event
          // never triggers a rebuild mid-build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            CourierBeacon.instance
                .syncActiveJobs(mine.map((j) => j['id'] as String).toList());
          });
          // Simple route hint: open jobs sharing an address word with one of
          // my active deliveries are likely "on the way".
          final myWords = mine
              .expand((j) =>
                  '${j['dropAddress']}'.toLowerCase().split(RegExp(r'[^a-z]+')))
              .where((w) => w.length > 3)
              .toSet();
          bool onTheWay(Map<String, dynamic> j) =>
              mine.isNotEmpty &&
              '${j['dropAddress']}'
                  .toLowerCase()
                  .split(RegExp(r'[^a-z]+'))
                  .any((w) => w.length > 3 && myWords.contains(w));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('${mine.length}',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: LhColors.navy)),
                            const Text('My deliveries',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: LhColors.inkSecondary)),
                          ],
                        ),
                      ),
                      Container(
                          width: 0.5, height: 34, color: LhColors.hairline),
                      Expanded(
                        child: Column(
                          children: [
                            Text('${open.length}',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: LhColors.blue)),
                            const Text('Open to claim',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: LhColors.inkSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (mine.isNotEmpty) ...[
                const SizedBox(height: 10),
                const _SharingBanner(),
              ],
              const SizedBox(height: 10),
              for (final j in [...mine, ...open]) ...[
                _DeliveryCard(
                    job: j, onTheWay: j['status'] == 'Open' && onTheWay(j)),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Tells the partner their location is being shared, and shows the last fix so
/// they can see it is genuinely working (or why it is not).
class _SharingBanner extends StatelessWidget {
  const _SharingBanner();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CourierBeacon.instance,
      builder: (context, _) {
        final b = CourierBeacon.instance;
        final err = b.lastError;
        final pos = b.lastPosition;
        final ok = b.sharing && err == null;
        return Card(
          color:
              (ok ? LhColors.green : LhColors.orange).withValues(alpha: 0.10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                    ok
                        ? CupertinoIcons.location_fill
                        : CupertinoIcons.exclamationmark_triangle_fill,
                    color: ok ? LhColors.green : LhColors.orange,
                    size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ok ? 'Sharing your location' : 'Location not shared',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                          err ??
                              (pos == null
                                  ? 'Getting your first GPS fix…'
                                  : 'The customer can see you moving on their '
                                      'map. Last fix '
                                      '${pos.latitude.toStringAsFixed(4)}, '
                                      '${pos.longitude.toStringAsFixed(4)}.'),
                          style: const TextStyle(
                              fontSize: 12.5, color: LhColors.inkSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final bool onTheWay;
  const _DeliveryCard({required this.job, this.onTheWay = false});

  Future<void> _act(BuildContext context) async {
    final fb = FirebaseService.instance;
    final id = job['id'] as String;
    final status = job['status'] as String;
    // The customer's contact details and delivery OTP live on the booking, not
    // on the job board every partner can read, so they are fetched here — a
    // read only the assigned partner is allowed to make.
    final private = status == 'Open' ? null : await fb.deliveryJobPrivate(id);
    if (!context.mounted) return;
    // Completing a delivery requires the customer's OTP.
    if (status == 'PickedUp') {
      final otpCtl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(CupertinoIcons.lock_shield_fill,
              color: LhColors.navy, size: 40),
          title: const Text('Enter customer OTP'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Ask the customer for the 4-digit code from their order '
                  'confirmation. This proves the delivery reached them.',
                  style:
                      TextStyle(fontSize: 13.5, color: LhColors.inkSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: otpCtl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8),
                decoration:
                    const InputDecoration(hintText: '••••', counterText: ''),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                style: dialogButtonStyle(),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm Delivery')),
          ],
        ),
      );
      if (ok != true) return;
      final expected = (private?['otp'] ?? '') as String;
      if (expected.isNotEmpty && otpCtl.text.trim() != expected) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Wrong OTP — ask the customer for the code in '
                  'their order message.')));
        }
        return;
      }
    }
    final notify = Booking(
      (job['storeName'] ?? '') as String,
      (job['orderDetail'] ?? '') as String,
      status,
      0,
      id: id,
      address: (job['dropAddress'] ?? '') as String,
      customerPhone: (private?['customerPhone'] ?? '') as String,
      customerEmail: (private?['customerEmail'] ?? '') as String,
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
      msg =
          'Delivered! Your \$${((job['fee'] ?? 0) as num).toStringAsFixed(2)} '
          'delivery fee is queued for payout.';
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  /// The job's contents, wrapped as a booking so the shared itemised view can
  /// render it. Only the goods are filled in — this card never holds the
  /// customer's private details.
  // The stream hands the job over as a raw map, so createdAt is still a
  // Firestore Timestamp; unwrap it dynamically to keep cloud_firestore out
  // of this screen's imports.
  DateTime? get _created {
    final v = job['createdAt'];
    if (v is DateTime) return v;
    if (v == null) return null;
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  Booking get _carrying => Booking(
        (job['storeName'] ?? '') as String,
        (job['orderDetail'] ?? '') as String,
        (job['status'] ?? '') as String,
        0,
        items: ((job['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => OrderLine.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        createdAt: _created,
      );

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
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                if (onTheWay)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: LhColors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('On your way!',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: LhColors.green)),
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
                style: const TextStyle(
                    fontSize: 13.5, color: LhColors.inkSecondary)),
            if (_carrying.placedLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(_carrying.placedLabel,
                    style: const TextStyle(
                        fontSize: 12, color: LhColors.inkSecondary)),
              ),
            // What is in the bag, so the partner can check the handover against
            // the order before leaving the store. No prices — what the customer
            // paid is between them and the business.
            if (_carrying.items.isNotEmpty) ...[
              const SizedBox(height: 10),
              OrderItemsView(
                  booking: _carrying, audience: OrderAudience.courier),
            ],
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
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DirectionsScreen(
                          title: 'Drop-off', address: '${job['dropAddress']}'),
                    ),
                  ),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                  icon:
                      const Icon(CupertinoIcons.arrow_turn_up_right, size: 14),
                  label:
                      const Text('Directions', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            if (mine) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(CupertinoIcons.location_north_line_fill,
                      size: 13, color: LhColors.green),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                        'The customer can see you on their map while this '
                        'delivery is active.',
                        style: TextStyle(
                            fontSize: 12.5, color: LhColors.inkSecondary)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrackDeliveryScreen(
                          jobId: job['id'] as String,
                          title: '${job['storeName']}',
                          dropAddress: '${job['dropAddress']}',
                        ),
                      ),
                    ),
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    child:
                        const Text('See map', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _act(context),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  backgroundColor:
                      status == 'Open' ? LhColors.blue : LhColors.navy),
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
