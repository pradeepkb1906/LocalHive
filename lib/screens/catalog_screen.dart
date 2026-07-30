import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/data.dart';
import 'directions_screen.dart';
import '../services/firebase_service.dart';
import '../theme.dart';
import '../widgets/location_chip.dart';
import 'profile_screen.dart';

/// Order-ahead catalog for Indian stores and food trucks. Placing an order
/// records a real booking in AppState.
class CatalogScreen extends StatefulWidget {
  final Provider provider;
  final List<CatalogItem> items;
  const CatalogScreen({super.key, required this.provider, required this.items});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final Map<CatalogItem, int> _cart = {};
  bool _delivery = false;
  bool _following = false;

  @override
  void initState() {
    super.initState();
    if (widget.provider.category == 'food_truck') {
      FirebaseService.instance
          .isFollowingTruck(widget.provider.id)
          .then((v) => mounted ? setState(() => _following = v) : null);
    }
  }

  Future<void> _toggleFollow() async {
    if (!AppState.instance.signedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sign in to get arrival alerts for this truck.')));
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const SignInScreen()));
      return;
    }
    if (_following) {
      await FirebaseService.instance.unfollowTruck(widget.provider.id);
      if (mounted) {
        setState(() => _following = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Arrival alerts turned off.')));
      }
      return;
    }
    final phoneCtl =
        TextEditingController(text: AppState.instance.userPhone ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(CupertinoIcons.bell_fill,
            color: LhColors.orange, size: 40),
        title: Text('Alert me when ${widget.provider.name} arrives'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'We\'ll text you the moment the truck announces it has arrived nearby.',
                style: TextStyle(fontSize: 14, color: LhColors.inkSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: phoneCtl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  hintText: 'Mobile number for the alert'),
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
              child: const Text('Notify Me')),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseService.instance.followTruck(widget.provider,
        phone: phoneCtl.text.trim(), email: AppState.instance.userEmail ?? '');
    if (mounted) {
      setState(() => _following = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'You\'ll be alerted when ${widget.provider.name} arrives!')));
    }
  }

  final _address = TextEditingController();
  static const _deliveryFee = 4.99;
  String _pickupEta = 'In 30 min';
  static const _etaOptions = [
    'In 15 min',
    'In 30 min',
    'In 45 min',
    'In 1 hour'
  ];

  double get _subtotal =>
      _cart.entries.fold(0, (sum, e) => sum + e.key.price * e.value);
  double get _fee => _subtotal * platformFeePct;
  double get _total => money(_subtotal + _fee + (_delivery ? _deliveryFee : 0));
  int get _count => _cart.values.fold(0, (a, b) => a + b);

  /// The cart, as lines recorded on the booking.
  ///
  /// The price is copied in rather than looked up later: this is what the
  /// customer agreed to pay, and it must not move if the business reprices the
  /// item tomorrow.
  List<OrderLine> _orderLines() => _cart.entries
      .map((e) => OrderLine(
            name: e.key.name,
            qty: e.value,
            unitPrice: e.key.price,
            unit: e.key.unit,
            emoji: e.key.emoji,
          ))
      .toList();

  /// One line describing the order, for notifications and for lists too tight
  /// to show every item. Names the first few items instead of just counting
  /// them, because "3 items" tells the person preparing it nothing.
  String _orderSummary() {
    final kind = _delivery ? 'Delivery' : 'Pickup';
    final lines = _cart.entries.toList();
    if (lines.isEmpty) return '$kind order';
    final named =
        lines.take(3).map((e) => '${e.value} × ${e.key.name}').join(', ');
    final rest = lines.length - 3;
    return '$kind order · $named${rest > 0 ? ' +$rest more' : ''}';
  }

  Color get _tint => widget.provider.category == 'indian_store'
      ? LhColors.green
      : LhColors.orange;

  void _checkout() {
    if (!AppState.instance.signedIn && AppState.instance.firebaseReady) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to place an order.')));
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const SignInScreen()));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: LhColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Order · ${widget.provider.name}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      label: Text('Pickup'),
                      icon: Icon(CupertinoIcons.bag)),
                  ButtonSegment(
                      value: true,
                      label: Text('Delivery +\$4.99'),
                      icon: Icon(CupertinoIcons.cube_box)),
                ],
                selected: {_delivery},
                onSelectionChanged: (s) =>
                    setSheet(() => setState(() => _delivery = s.first)),
              ),
              if (_delivery) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _address,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      hintText: 'Delivery address (street, city, state)'),
                ),
              ] else ...[
                const SizedBox(height: 12),
                const Text('When will you arrive?',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _etaOptions
                      .map((e) => ChoiceChip(
                          label: Text(e),
                          selected: _pickupEta == e,
                          onSelected: (_) =>
                              setSheet(() => setState(() => _pickupEta = e))))
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ..._cart.entries.map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                    child: Text('${e.value} × ${e.key.name}',
                                        style:
                                            const TextStyle(fontSize: 14.5))),
                                Text(
                                    '\$${(e.key.price * e.value).toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 14.5)),
                              ],
                            ),
                          )),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider()),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Platform fee (12%)',
                              style: TextStyle(fontSize: 14.5)),
                          Text('\$${_fee.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 14.5)),
                        ],
                      ),
                      if (_delivery) ...[
                        const SizedBox(height: 4),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Delivery fee',
                                style: TextStyle(fontSize: 14.5)),
                            Text('\$4.99', style: TextStyle(fontSize: 14.5)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 17)),
                          Text('\$${_total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 17)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (_delivery && _address.text.trim().length < 8) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Enter the full delivery address.')));
                    return;
                  }
                  AppState.instance.addBooking(Booking(
                    widget.provider.name,
                    _orderSummary(),
                    'Placed',
                    _total,
                    items: _orderLines(),
                    providerId: widget.provider.id,
                    category: widget.provider.category,
                    address: _delivery ? _address.text.trim() : '',
                    customerName: AppState.instance.userName ?? '',
                    customerPhone: AppState.instance.userPhone ?? '',
                    customerEmail: AppState.instance.userEmail ?? '',
                    fulfillment: _delivery ? 'delivery' : 'pickup',
                    pickupEta: _delivery ? '' : _pickupEta,
                  ));
                  Navigator.pop(ctx);
                  setState(() => _cart.clear());
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(_delivery
                          ? 'Order placed for delivery — track it in the Bookings tab.'
                          : 'Pickup order placed — track it in the Bookings tab.')));
                },
                child: Text(
                    _delivery ? 'Place Delivery Order' : 'Place Pickup Order'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.provider.name),
        actions: [
          if (widget.provider.category == 'food_truck')
            IconButton(
              tooltip:
                  _following ? 'Arrival alerts on' : 'Notify me on arrival',
              icon: Icon(
                  _following ? CupertinoIcons.bell_fill : CupertinoIcons.bell,
                  size: 20,
                  color: _following ? LhColors.orange : null),
              onPressed: _toggleFollow,
            ),
          IconButton(
            tooltip: 'Get directions',
            icon: const Icon(CupertinoIcons.arrow_turn_up_right, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DirectionsScreen(
                  title: widget.provider.name,
                  address: widget.provider.city,
                  lat: widget.provider.lat,
                  lng: widget.provider.lng,
                ),
              ),
            ),
          ),
          const LocationChip(),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.location_solid,
                    size: 12, color: LhColors.inkSecondary),
                const SizedBox(width: 3),
                Flexible(
                  child: Text('${widget.provider.city}  ·  ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: LhColors.inkSecondary)),
                ),
                const Icon(CupertinoIcons.star_fill,
                    size: 12, color: LhColors.amber),
                const SizedBox(width: 3),
                Text('${widget.provider.rating}',
                    style: const TextStyle(
                        fontSize: 13, color: LhColors.inkSecondary)),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < widget.items.length; i++) ...[
                  _itemRow(widget.items[i]),
                  if (i != widget.items.length - 1)
                    const Padding(
                        padding: EdgeInsets.only(left: 66), child: Divider()),
                ]
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _count == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _checkout,
                  child: Text(
                      'View Cart · $_count item${_count > 1 ? 's' : ''} · \$${_total.toStringAsFixed(2)}'),
                ),
              ),
            ),
    );
  }

  Widget _itemRow(CatalogItem item) {
    final qty = _cart[item] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: _tint.withValues(alpha: 0.14),
            child: Text(item.name.substring(0, 1),
                style: TextStyle(
                    color: _tint, fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('\$${item.price.toStringAsFixed(2)} / ${item.unit}',
                    style: const TextStyle(
                        fontSize: 13, color: LhColors.inkSecondary)),
              ],
            ),
          ),
          if (qty == 0)
            OutlinedButton(
              onPressed: () => setState(() => _cart[item] = 1),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: const Text('Add'),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(CupertinoIcons.minus_circle,
                      size: 24, color: LhColors.inkSecondary),
                  onPressed: () => setState(() {
                    if (qty == 1) {
                      _cart.remove(item);
                    } else {
                      _cart[item] = qty - 1;
                    }
                  }),
                ),
                SizedBox(
                    width: 22,
                    child: Center(
                        child: Text('$qty',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(CupertinoIcons.plus_circle_fill,
                      size: 24, color: LhColors.blue),
                  onPressed: () => setState(() => _cart[item] = qty + 1),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
