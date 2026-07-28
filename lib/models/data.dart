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
  });
}

class CatalogItem {
  final String name;
  final double price;
  final String unit;
  final String emoji;
  const CatalogItem(this.name, this.price, this.unit, this.emoji);
}

class Booking {
  final String providerName;
  final String detail;
  final String status;
  final double amount;
  const Booking(this.providerName, this.detail, this.status, this.amount);
}

const platformFeePct = 0.12; // 12% platform fee, shown transparently at checkout

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
      subtitle: 'Vada pav · pav bhaji · open till 9 PM',
      rating: 4.9,
      reviews: 310,
      city: 'Near Oak Tree Rd, Edison',
      emoji: '🚚'),
  Provider(
      id: 'ft2',
      name: 'Hyderabad House on Wheels',
      category: 'food_truck',
      subtitle: 'Biryani · haleem · open till 10 PM',
      rating: 4.8,
      reviews: 275,
      city: 'Downtown Iselin',
      emoji: '🍛'),
  Provider(
      id: 'ft3',
      name: 'Chaat Chowk Truck',
      category: 'food_truck',
      subtitle: 'Pani puri · bhel · sev puri',
      rating: 4.7,
      reviews: 142,
      city: 'Menlo Park Mall lot',
      emoji: '🥟'),
];

const storeCatalog = [
  CatalogItem('Basmati Rice 10 lb', 14.99, 'bag', '🍚'),
  CatalogItem('Toor Dal 4 lb', 7.49, 'bag', '🫘'),
  CatalogItem('Fresh Dosa Batter', 5.99, 'tub', '🥞'),
  CatalogItem('Garam Masala', 3.99, '100 g', '🌶️'),
  CatalogItem('Paneer', 6.49, '14 oz', '🧀'),
  CatalogItem('Frozen Samosas (12)', 8.99, 'box', '🥟'),
  CatalogItem('Mango Pickle', 4.49, 'jar', '🥭'),
  CatalogItem('Atta Whole Wheat 20 lb', 18.99, 'bag', '🌾'),
];

const truckMenu = [
  CatalogItem('Vada Pav', 4.50, 'each', '🍔'),
  CatalogItem('Pav Bhaji', 8.99, 'plate', '🍲'),
  CatalogItem('Chicken Biryani', 12.99, 'box', '🍛'),
  CatalogItem('Pani Puri', 6.99, '8 pc', '🥟'),
  CatalogItem('Masala Chai', 2.50, 'cup', '☕'),
  CatalogItem('Mango Lassi', 4.99, 'cup', '🥭'),
];

final myBookings = <Booking>[
  const Booking('Maria G.', 'House cleaning · Sat 10 AM · 3 hrs', 'Confirmed', 94.08),
  const Booking('Bombay Street Eats', 'Pickup order · 2 items', 'Ready at 6:30 PM', 13.49),
];
