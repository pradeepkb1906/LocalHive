// Mock data layer for the LocalHive MVP.
// In production this is replaced by Firestore queries; keeping the shapes
// identical to the planned Firestore documents makes that swap mechanical.

class Provider {
  final String id;
  final String name;
  final String category; // 'home_service' | 'indian_store' | 'food_truck'
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

  /// Food trucks only: what kind of food this truck serves. One of
  /// 'american' | 'mexican' | 'chinese' | 'italian' | 'indian'; empty means
  /// unknown, which gets the American menu — the safe default for a US truck.
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

const homeServiceProviders = [
  Provider(
      id: 'hs1',
      name: 'Maria G.',
      category: 'home_service',
      subtitle: 'House cleaning · deep clean specialist',
      rating: 4.9,
      reviews: 212,
      hourlyRate: 28,
      city: 'Edison, NJ',
      emoji: '🧹'),
  Provider(
      id: 'hs2',
      name: 'Dave R.',
      category: 'home_service',
      subtitle: 'Handyman · furniture, mounting, small repairs',
      rating: 4.8,
      reviews: 158,
      hourlyRate: 45,
      city: 'Edison, NJ',
      emoji: '🔧'),
  Provider(
      id: 'hs3',
      name: 'Lakshmi P.',
      category: 'home_service',
      subtitle: 'House cleaning · move-in / move-out',
      rating: 4.7,
      reviews: 96,
      hourlyRate: 30,
      city: 'Iselin, NJ',
      emoji: '🧼'),
  Provider(
      id: 'hs4',
      name: 'Tom W.',
      category: 'home_service',
      subtitle: 'Handyman · painting & drywall',
      rating: 4.6,
      reviews: 74,
      hourlyRate: 40,
      city: 'Woodbridge, NJ',
      emoji: '🎨'),
];

const indianStores = [
  Provider(
      id: 'st1',
      name: 'Patel Brothers Express',
      category: 'indian_store',
      subtitle: 'Groceries · spices · fresh produce',
      rating: 4.8,
      reviews: 431,
      city: 'Edison, NJ',
      emoji: '🛒'),
  Provider(
      id: 'st2',
      name: 'Desi Bazaar',
      category: 'indian_store',
      subtitle: 'Snacks · sweets · pooja items',
      rating: 4.6,
      reviews: 189,
      city: 'Iselin, NJ',
      emoji: '🪔'),
  Provider(
      id: 'st3',
      name: 'Chennai Cash & Carry',
      category: 'indian_store',
      subtitle: 'South Indian groceries · fresh dosa batter',
      rating: 4.7,
      reviews: 240,
      city: 'Parsippany, NJ',
      emoji: '🥥'),
];

const foodTrucks = [
  Provider(
      id: 'ft1',
      name: 'Bombay Street Eats',
      category: 'food_truck',
      cuisine: 'indian',
      subtitle: 'Vada pav · pav bhaji · open till 9 PM',
      rating: 4.9,
      reviews: 310,
      city: 'Near Oak Tree Rd, Edison',
      emoji: '🚚',
      lat: 40.5629,
      lng: -74.3390),
  Provider(
      id: 'ft2',
      name: 'Hyderabad House on Wheels',
      category: 'food_truck',
      cuisine: 'indian',
      subtitle: 'Biryani · haleem · open till 10 PM',
      rating: 4.8,
      reviews: 275,
      city: 'Downtown Iselin',
      emoji: '🍛',
      lat: 40.5754,
      lng: -74.3223),
  Provider(
      id: 'ft3',
      name: 'Chaat Chowk Truck',
      category: 'food_truck',
      cuisine: 'indian',
      subtitle: 'Pani puri · bhel · sev puri',
      rating: 4.7,
      reviews: 142,
      city: 'Menlo Park Mall lot',
      emoji: '🥟',
      lat: 40.5478,
      lng: -74.3355),
];

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

/// One menu per cuisine, so a taco truck sells tacos and a noodle truck sells
/// noodles. Chosen per provider via [truckMenuFor].
const _americanMenu = [
  CatalogItem('Classic Cheeseburger', 9.99, 'each', '🍔'),
  CatalogItem('BBQ Pulled Pork Sandwich', 10.49, 'each', '🥪'),
  CatalogItem('All-Beef Hot Dog', 5.49, 'each', '🌭'),
  CatalogItem('Loaded Fries', 6.99, 'basket', '🍟'),
  CatalogItem('Vanilla Milkshake', 5.49, 'cup', '🥤'),
  CatalogItem('Apple Pie Slice', 3.99, 'slice', '🥧'),
];

const _mexicanMenu = [
  CatalogItem('Tacos al Pastor', 9.49, '3 pc', '🌮'),
  CatalogItem('Chicken Quesadilla', 9.99, 'each', '🫓'),
  CatalogItem('Carne Asada Burrito', 11.49, 'each', '🌯'),
  CatalogItem('Chips & Guacamole', 5.99, 'basket', '🥑'),
  CatalogItem('Street Corn (Elote)', 4.49, 'each', '🌽'),
  CatalogItem('Horchata', 3.99, 'cup', '🥤'),
];

const _chineseMenu = [
  CatalogItem('Chicken Fried Rice', 10.49, 'box', '🍚'),
  CatalogItem('Vegetable Chow Mein', 9.49, 'box', '🍜'),
  CatalogItem('Kung Pao Chicken', 11.99, 'box', '🌶️'),
  CatalogItem('Pork Dumplings', 7.99, '6 pc', '🥟'),
  CatalogItem('Spring Rolls', 5.49, '4 pc', '🥢'),
  CatalogItem('Bubble Tea', 5.49, 'cup', '🧋'),
];

const _italianMenu = [
  CatalogItem('Margherita Slice', 4.99, 'slice', '🍕'),
  CatalogItem('Pepperoni Slice', 5.49, 'slice', '🍕'),
  CatalogItem('Chicken Parm Sandwich', 10.99, 'each', '🥖'),
  CatalogItem('Penne Alfredo', 11.49, 'box', '🍝'),
  CatalogItem('Garlic Knots', 4.99, '6 pc', '🧄'),
  CatalogItem('Cannoli', 4.49, 'each', '🍰'),
];

const _indianMenu = [
  CatalogItem('Vada Pav', 4.50, 'each', '🍔'),
  CatalogItem('Pav Bhaji', 8.99, 'plate', '🍲'),
  CatalogItem('Chicken Biryani', 12.99, 'box', '🍛'),
  CatalogItem('Pani Puri', 6.99, '8 pc', '🥟'),
  CatalogItem('Masala Chai', 2.50, 'cup', '☕'),
  CatalogItem('Mango Lassi', 4.99, 'cup', '🥭'),
];

/// The menu a given truck actually serves.
///
/// American is the default for a truck with no recorded cuisine: every truck
/// seeded before cuisines existed was Indian, so those carry
/// cuisine: 'indian' explicitly, and an unknown truck in a US city is more
/// likely burgers than biryani.
List<CatalogItem> truckMenuFor(String cuisine) => switch (cuisine) {
      'mexican' => _mexicanMenu,
      'chinese' => _chineseMenu,
      'italian' => _italianMenu,
      'indian' => _indianMenu,
      _ => _americanMenu,
    };

/// The historic single truck menu — the demo trucks are all Indian.
const truckMenu = _indianMenu;

final myBookings = <Booking>[
  const Booking(
      'Maria G.', 'House cleaning · Sat 10 AM · 3 hrs', 'Confirmed', 94.08),
  const Booking('Bombay Street Eats', 'Pickup order · 2 items',
      'Ready at 6:30 PM', 13.49),
];
