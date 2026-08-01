import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/data.dart';
import '../services/geo.dart';
import '../services/supabase_mirror.dart';
import '../theme.dart';
import '../widgets/address_field.dart';
import '../widgets/location_chip.dart';
import 'profile_screen.dart';

/// Order-ahead catalog for a grocery store. Placing an order records a real
/// booking in AppState.
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

  final _address = TextEditingController();
  final _deliveryNote = TextEditingController();
  bool _needsHelp = false;
  static const _deliveryFee = 4.99;
  String _pickupEta = 'In 30 min';
  static const _etaOptions = [
    'In 15 min',
    'In 30 min',
    'In 45 min',
    'In 1 hour'
  ];

  @override
  void dispose() {
    _address.dispose();
    _deliveryNote.dispose();
    super.dispose();
  }

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

  Color get _tint => LhColors.green;

  bool _placingOrder = false;

  void _checkout() {
    if (!AppState.instance.signedIn && AppState.instance.firebaseReady) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to place an order.')));
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const SignInScreen()));
      return;
    }
    // A closed business cannot cook or pack anything. Only enforced when the
    // listing declares hours — unknown hours give the benefit of the doubt.
    final prov = widget.provider;
    if (prov.availableFrom.isNotEmpty &&
        prov.availableTo.isNotEmpty &&
        !isOpenAt(prov.availableFrom, prov.availableTo, DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${prov.name} is closed right now — open '
              '${prov.availableFrom} to ${prov.availableTo}. '
              'Come back then!')));
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
                AddressField(
                  controller: _address,
                  hintText: 'Delivery address (street, city, state)',
                ),
                const SizedBox(height: 4),
                // Asking for help is free to the customer — the extra goes to
                // the partner out of the platform's cut. Someone who struggles
                // with a heavy bag should not have to pay more to say so.
                CheckboxListTile(
                  value: _needsHelp,
                  onChanged: (v) =>
                      setSheet(() => setState(() => _needsHelp = v ?? false)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('I need a hand to the door',
                      style: TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                      'Heavy bags, stairs, limited mobility. Free for you — '
                      'your delivery partner is paid extra for it.',
                      style: TextStyle(
                          fontSize: 12.5, color: LhColors.inkSecondary)),
                ),
                TextField(
                  controller: _deliveryNote,
                  maxLength: 140,
                  decoration: const InputDecoration(
                    hintText: 'Note for your delivery partner (optional)',
                    helperText: 'Gate code, buzzer, "ring twice — I am slow '
                        'to the door"',
                    counterText: '',
                  ),
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
              // On the standby catalog there is nowhere to write an order.
              // Saying so and disabling the button is the only honest option:
              // an order that silently goes nowhere is worse than a customer
              // who knows to phone the shop instead.
              if (SupabaseMirror.instance.servingFromMirror) ...[
                Card(
                  color: LhColors.orange.withValues(alpha: 0.12),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.exclamationmark_triangle_fill,
                            size: 18, color: LhColors.orange),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              'Ordering is paused while the main service is '
                              'unreachable. Your basket is safe — or call the '
                              'shop directly.',
                              style: TextStyle(fontSize: 12.5, height: 1.3)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              FilledButton(
                onPressed: _placingOrder ||
                        SupabaseMirror.instance.servingFromMirror
                    ? null
                    : () async {
                        if (_delivery && _address.text.trim().length < 8) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content:
                                  Text('Enter the full delivery address.')));
                          return;
                        }
                        // Guarded and awaited: a double-tap here used to place
                        // the same order twice.
                        setSheet(() => setState(() => _placingOrder = true));
                        final placedId =
                            await AppState.instance.addBookingAndWait(Booking(
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
                          needsHelp: _delivery && _needsHelp,
                          deliveryNote:
                              _delivery ? _deliveryNote.text.trim() : '',
                        ));
                        // Only clear the basket and claim success if the
                        // order actually reached the backend. Telling someone
                        // their groceries are on the way when nothing was
                        // recorded is the one failure that cannot be walked
                        // back later.
                        if (placedId == null) {
                          if (!mounted) return;
                          setState(() => _placingOrder = false);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text(
                                  'Could not place your order — the service is '
                                  'unreachable. Your basket is still here; '
                                  'please try again or call the shop.')));
                          return;
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        setState(() {
                          _cart.clear();
                          _placingOrder = false;
                          _needsHelp = false;
                          _deliveryNote.clear();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(_delivery
                                ? 'Order placed for delivery — track it in the Bookings tab.'
                                : 'Pickup order placed — track it in the Bookings tab.')));
                      },
                child: Text(_placingOrder
                    ? 'Placing…'
                    : _delivery
                        ? 'Place Delivery Order'
                        : 'Place Pickup Order'),
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
