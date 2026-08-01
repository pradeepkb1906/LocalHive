// Shared models and the grocery catalog.
//
// The demo catalogs for food trucks and home services were deleted when
// LocalHive narrowed to one market and one vertical — San Francisco
// groceries. Listings now come from Firestore and belong to real shops
// that opted in; nothing is invented in the client.

class Provider {
  final String id;
  final String name;

  /// Only 'indian_store' (grocery) is live. The other category values
  /// remain readable so historic bookings still render.
  final String category;
  final String subtitle;
  final double rating;
  final int reviews;
  final double hourlyRate; // home services only
  final String city;
  final bool verified;
  final String emoji;
  final double lat; // 0 = unknown
  final double lng;
  final String availableFrom; // e.g. '9 AM'
  final String availableTo; // e.g. '6 PM'

  /// Kept for historic listings; unused now that groceries are the only
  /// live vertical.
  final String cuisine;

  const Provider({
    required this.id,
    required this.name,
    required this.category,
    required this.subtitle,
    required this.rating,
    required this.reviews,
    this.hourlyRate = 0,
    required this.city,
    this.verified = true,
    required this.emoji,
    this.lat = 0,
    this.lng = 0,
    this.availableFrom = '',
    this.availableTo = '',
    this.cuisine = '',
  });

  bool get hasLocation => lat != 0 || lng != 0;
  String get availability => availableFrom.isNotEmpty && availableTo.isNotEmpty
      ? '$availableFrom – $availableTo'
      : '';
}

class CatalogItem {
  final String name;
  final double price;
  final String unit;
  final String emoji;
  const CatalogItem(this.name, this.price, this.unit, this.emoji);
}

/// One line of a placed order: what was bought, how many, and at what price.
///
/// Stored on the booking itself rather than derived from the catalog, because a
/// receipt has to say what was charged at the time. If the store later reprices
/// an item or stops selling it, an order already placed must not change.
class OrderLine {
  final String name;
  final int qty;
  final double unitPrice;
  final String unit;
  final String emoji;

  const OrderLine({
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.unit = '',
    this.emoji = '',
  });

  double get lineTotal => unitPrice * qty;

  Map<String, dynamic> toMap() => {
        'name': name,
        'qty': qty,
        'unitPrice': unitPrice,
        if (unit.isNotEmpty) 'unit': unit,
        if (emoji.isNotEmpty) 'emoji': emoji,
      };

  /// Tolerant of missing or wrongly typed fields: these documents are written by
  /// several versions of the app, and half a line is more useful to the person
  /// packing the order than no line at all.
  static OrderLine fromMap(Map<String, dynamic> m) => OrderLine(
        name: (m['name'] ?? '') as String,
        qty: (m['qty'] as num?)?.toInt() ?? 1,
        unitPrice: (m['unitPrice'] as num?)?.toDouble() ?? 0,
        unit: (m['unit'] ?? '') as String,
        emoji: (m['emoji'] ?? '') as String,
      );
}

/// What a delivery partner is paid for one run, and the extra they earn when
/// the customer has asked for help to the door. The helping hand is paid for
/// by the platform's cut, not added to the customer's bill: the people most
/// likely to need it are the least able to pay more for it.
const double courierBaseFee = 4.99;
const double courierHelpBonus = 3.00;

/// A delivery address reduced to something safe to publish on the open job
/// board: everything after the street line, so "550 Divisadero St, San
/// Francisco, CA" becomes "San Francisco, CA".
///
/// A courier deciding whether to take a job needs to know roughly where it
/// goes. They do not need — and should not have, before they are assigned —
/// the door number of someone who is about to be home waiting for a delivery.
String coarseArea(String address) {
  final parts = address.split(',').map((p) => p.trim()).toList()
    ..removeWhere((p) => p.isEmpty);
  if (parts.length <= 1) return parts.isEmpty ? '' : parts.first;
  return parts.sublist(1).join(', ');
}

double courierFeeFor({required bool needsHelp}) =>
    needsHelp ? courierBaseFee + courierHelpBonus : courierBaseFee;

class Booking {
  final String providerName;
  final String detail;
  final String
      status; // Requested | Accepted | Declined | Completed | Preparing
  final double amount;
  final String id; // Firestore doc id ('' for local/mock)
  final String providerId;
  final String category;
  final String address; // service or delivery address
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String fulfillment; // '' | 'pickup' | 'delivery'
  final String pickupEta; // customer's stated arrival, pickup orders
  final String otp; // 4-digit delivery confirmation code

  /// The two uids on either side of this booking, for opening a chat.
  final String userId;
  final String providerOwnerId;

  /// What was ordered. Empty for home-service bookings, which are hours of
  /// someone's time rather than a list of goods.
  final List<OrderLine> items;

  /// The customer has asked for help getting the order to their door —
  /// a senior, someone with limited mobility, or simply a heavy shop. The
  /// delivery partner sees this before claiming, and is paid extra for it.
  final bool needsHelp;

  /// Anything the partner needs to know on arrival: a gate code, "ring twice,
  /// I am slow to the door", "leave with the neighbour". Shown on the job.
  final String deliveryNote;

  /// When this booking was placed — the server's clock, not the phone's.
  /// Null only for mock rows and documents from before it was recorded.
  final DateTime? createdAt;

  const Booking(
    this.providerName,
    this.detail,
    this.status,
    this.amount, {
    this.id = '',
    this.providerId = '',
    this.category = '',
    this.address = '',
    this.customerName = '',
    this.customerPhone = '',
    this.customerEmail = '',
    this.fulfillment = '',
    this.pickupEta = '',
    this.otp = '',
    this.userId = '',
    this.providerOwnerId = '',
    this.items = const [],
    this.needsHelp = false,
    this.deliveryNote = '',
    this.createdAt,
  });

  /// Still moving through its lifecycle, as opposed to settled history.
  bool get isActive => !const {
        'Completed',
        'Delivered',
        'Declined',
        'Cancelled'
      }.contains(status);

  /// A home-service visit can be called off any time before the provider
  /// commits to it — the standard cancellation window of every booking app.
  bool get canCancel => status == 'Requested' && id.isNotEmpty;

  /// "Placed today 7:42 PM" / "Placed Jul 30, 7:42 PM" — every ordering app
  /// answers "when did I order this?" without being asked.
  String get placedLabel {
    final t = createdAt;
    if (t == null) return '';
    final local = t.toLocal();
    final now = DateTime.now();
    final h12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final time = '$h12:${local.minute.toString().padLeft(2, '0')} '
        '${local.hour < 12 ? 'AM' : 'PM'}';
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) return 'Placed today $time';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final date = '${months[local.month - 1]} ${local.day}'
        '${local.year == now.year ? '' : ', ${local.year}'}';
    return 'Placed $date, $time';
  }

  /// What the goods came to, before the platform fee and any delivery charge.
  double get itemsSubtotal =>
      items.fold(0.0, (sum, line) => sum + line.lineTotal);

  int get itemCount => items.fold(0, (sum, line) => sum + line.qty);
}

const platformFeePct =
    0.12; // 12% platform fee, shown transparently at checkout

/// Rounds an amount to whole cents.
///
/// A 12% fee on an odd subtotal gives fractions of a cent — $45.8752 — and that
/// was being stored as the price of an order. It displayed as $45.88 because
/// every label formats to two places, so it looked right while the recorded
/// figure was not a payable amount. Anything that becomes money someone hands
/// over goes through here first.
double money(double amount) => (amount * 100).round() / 100;

/// Everyday groceries any US store carries. Kept brand-free and cuisine-free
/// so one catalog serves every store in every city.
const storeCatalog = [
  CatalogItem('Rice 10 lb', 12.99, 'bag', '🍚'),
  CatalogItem('Eggs', 4.49, 'dozen', '🥚'),
  CatalogItem('Whole Milk', 3.99, 'gallon', '🥛'),
  CatalogItem('Bread', 3.49, 'loaf', '🍞'),
  CatalogItem('Chicken Breast 2 lb', 8.99, 'pack', '🍗'),
  CatalogItem('Pasta', 2.49, '1 lb box', '🍝'),
  CatalogItem('Olive Oil', 9.99, '500 ml', '🫒'),
  CatalogItem('Fresh Produce Box', 14.99, 'box', '🥬'),
];

final myBookings = <Booking>[
  const Booking(
      'Maria G.', 'House cleaning · Sat 10 AM · 3 hrs', 'Confirmed', 94.08),
  const Booking('Bombay Street Eats', 'Pickup order · 2 items',
      'Ready at 6:30 PM', 13.49),
];
