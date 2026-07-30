import '../../models/data.dart';

/// One line of a proposed order.
class DraftLine {
  final String name;
  final int qty;
  final double unitPrice;
  final String unit;
  final String emoji;

  const DraftLine({
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.unit = '',
    this.emoji = '',
  });

  double get lineTotal => unitPrice * qty;

  Map<String, dynamic> toJson() => {
        'name': name,
        'qty': qty,
        'unit_price': '\$${unitPrice.toStringAsFixed(2)}',
        'line_total': '\$${lineTotal.toStringAsFixed(2)}',
      };
}

/// An order Olivia has worked out but has NOT placed.
///
/// This is the heart of the safety design: the language model can produce a
/// draft, but only a human confirmation turns one into a [Booking]. That means
/// a misheard quantity is visible before it costs anything, and text smuggled
/// into a business listing cannot cause a write.
class OrderDraft {
  /// 'order' for food/grocery, 'home_service' for a booked visit.
  final String kind;
  final String providerId;
  final String providerName;
  final String category;

  // Food and grocery orders
  final List<DraftLine> lines;
  final String fulfillment; // 'pickup' | 'delivery'
  final String pickupEta;

  // Home service bookings
  final String dayLabel;
  final String slot;
  final int hours;
  final double hourlyRate;

  final String address;
  final String customerName;
  final String customerPhone;
  final String customerEmail;

  const OrderDraft({
    required this.kind,
    required this.providerId,
    required this.providerName,
    required this.category,
    this.lines = const [],
    this.fulfillment = '',
    this.pickupEta = '',
    this.dayLabel = '',
    this.slot = '',
    this.hours = 0,
    this.hourlyRate = 0,
    this.address = '',
    this.customerName = '',
    this.customerPhone = '',
    this.customerEmail = '',
  });

  static const deliveryFee = 4.99;

  static String _money(double v) => '\$${v.toStringAsFixed(2)}';

  bool get isDelivery => fulfillment == 'delivery';

  double get subtotal => kind == 'home_service'
      ? hourlyRate * hours
      : lines.fold(0, (sum, l) => sum + l.lineTotal);

  double get platformFee => subtotal * platformFeePct;

  double get deliveryCharge => isDelivery ? deliveryFee : 0;

  double get total => subtotal + platformFee + deliveryCharge;

  /// What the business actually receives, before the platform's cut.
  double get providerPayout => subtotal;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.qty);

  /// Human-readable order line stored on the booking. The tap-driven screens
  /// only record an item count; Olivia records the actual items so the
  /// business can read the order without calling the customer.
  String get detail {
    if (kind == 'home_service') {
      return '$dayLabel $slot · $hours hrs';
    }
    final items = lines.map((l) => '${l.qty} × ${l.name}').join(', ');
    return '${isDelivery ? 'Delivery' : 'Pickup'} order · $items';
  }

  /// Everything blocking confirmation, phrased so Olivia can say it aloud.
  List<String> get blockers => [
        if (providerId.isEmpty) 'I could not identify the business.',
        if (kind != 'home_service' && lines.isEmpty)
          'There are no items on this order yet.',
        if (isDelivery && address.trim().length < 8)
          'I need a full delivery address, including the street and town.',
        if (kind == 'home_service' && address.trim().length < 8)
          'I need the address where the work should happen.',
        if (kind == 'home_service' && hours <= 0)
          'I need to know how many hours you need.',
      ];

  bool get isReady => blockers.isEmpty;

  Booking toBooking() => Booking(
        providerName,
        detail,
        kind == 'home_service' ? 'Requested' : 'Placed',
        double.parse(total.toStringAsFixed(2)),
        providerId: providerId,
        category: category,
        address: address,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        fulfillment: kind == 'home_service' ? '' : fulfillment,
        pickupEta: kind == 'home_service' ? '' : pickupEta,
      );

  /// The summary Olivia reads back, and what gets returned to the model so it
  /// can describe the order accurately rather than inventing a total.
  ///
  /// Money is formatted as text rather than left as a number: Olivia says this
  /// out loud, and a raw 29.1 gets spoken as "twenty nine point one".
  Map<String, dynamic> toJson() => {
        'kind': kind,
        'business': providerName,
        if (lines.isNotEmpty) 'items': lines.map((l) => l.toJson()).toList(),
        if (kind == 'home_service') ...{
          'when': '$dayLabel at $slot',
          'hours': hours,
          'hourly_rate': _money(hourlyRate),
        },
        if (fulfillment.isNotEmpty) 'fulfillment': fulfillment,
        if (pickupEta.isNotEmpty) 'customer_arriving': pickupEta,
        if (address.isNotEmpty) 'address': address,
        'subtotal': _money(subtotal),
        'platform_fee': _money(platformFee),
        if (deliveryCharge > 0) 'delivery_fee': _money(deliveryCharge),
        'total': _money(total),
        'payment':
            'Paid in person on arrival — LocalHive takes no card details.',
        'ready_to_confirm': isReady,
        if (!isReady) 'still_needed': blockers,
        'note':
            'This is a draft. It is shown to the customer on screen and is only '
                'placed when they confirm it themselves.',
      };
}
