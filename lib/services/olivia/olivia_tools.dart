import 'package:flutter/foundation.dart';

import '../../app_state.dart';
import '../../models/data.dart';
import '../firebase_service.dart';
import '../geo.dart';
import '../location_service.dart';
import 'order_draft.dart';
import 'places_search.dart';

/// The tools Olivia can call, and the Dart that runs them.
///
/// Note what is absent: there is no `place_order`. Every ordering tool is a
/// `draft_*` that computes and returns a proposal. Writing to Firestore happens
/// only when the customer confirms the draft on screen. That keeps a misheard
/// quantity — or instructions smuggled into a business's name — from ever
/// reaching the database.
class OliviaTools {
  OliviaTools({FirebaseService? firebase, AppState? appState})
      : _fb = firebase ?? FirebaseService.instance,
        _app = appState ?? AppState.instance;

  final FirebaseService _fb;
  final AppState _app;
  final PlacesSearch _places = PlacesSearch();

  /// Set when a draft tool runs, so the screen can show the confirmation card.
  OrderDraft? pendingDraft;

  /// Whether a support ticket was actually raised while handling the current
  /// question. Used to catch Olivia promising a follow-up she never filed.
  bool raisedTicketThisTurn = false;

  static const _categories = ['food_truck', 'home_service', 'indian_store'];

  static const homeServiceSlots = ['8:00 AM', '10:00 AM', '1:00 PM', '3:00 PM'];
  static const homeServiceDays = [
    'Today',
    'Tomorrow',
    'In 2 days',
    'In 3 days',
    'In 4 days'
  ];
  static const pickupEtas = [
    'In 15 min',
    'In 30 min',
    'In 45 min',
    'In 1 hour'
  ];

  // ---------------------------------------------------------------- schemas

  static List<Map<String, dynamic>> get schemas => [
        {
          'type': 'function',
          'function': {
            'name': 'find_businesses',
            'description':
                'Find LocalHive businesses near the customer. Use this before '
                    'talking about any specific business — never invent one. '
                    'Returns only businesses that can actually receive orders.',
            'parameters': {
              'type': 'object',
              'properties': {
                'category': {
                  'type': 'string',
                  'enum': _categories,
                  'description':
                      'food_truck for cooked food to eat now — biryani, chaat, '
                          'vada pav, dosa, chai. indian_store for groceries and '
                          'ingredients to cook with — rice, dal, spices, paneer. '
                          'home_service for cleaners and handymen. If the '
                          'customer is hungry, it is food_truck.',
                },
                'query': {
                  'type': 'string',
                  'description':
                      'Optional keyword, e.g. a dish, cuisine or type of work.',
                },
                'open_now': {
                  'type': 'boolean',
                  'description':
                      'Only businesses currently inside their opening hours.',
                },
              },
              'required': ['category'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'get_menu',
            'description':
                'List what a food truck or grocery store sells, with prices. '
                    'Call this before drafting an order so prices are real.',
            'parameters': {
              'type': 'object',
              'properties': {
                'business_id': {'type': 'string'},
              },
              'required': ['business_id'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'draft_order',
            'description':
                'Work out a food or grocery order and show it to the customer '
                    'for confirmation. This does NOT place the order — the '
                    'customer confirms it themselves on screen. Call it as soon '
                    'as you know the items; missing details come back in '
                    'still_needed so you can ask for them.',
            'parameters': {
              'type': 'object',
              'properties': {
                'business_id': {'type': 'string'},
                'items': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'name': {
                        'type': 'string',
                        'description': 'Menu item name as returned by get_menu.'
                      },
                      'qty': {'type': 'integer', 'minimum': 1},
                    },
                    'required': ['name', 'qty'],
                  },
                },
                'fulfillment': {
                  'type': 'string',
                  'enum': ['pickup', 'delivery'],
                },
                'address': {
                  'type': 'string',
                  'description': 'Full street address. Required for delivery.',
                },
                'pickup_eta': {
                  'type': 'string',
                  'enum': pickupEtas,
                  'description': 'When the customer will arrive, for pickup.',
                },
              },
              'required': ['business_id', 'items', 'fulfillment'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'draft_home_service',
            'description':
                'Work out a home-service booking and show it to the customer '
                    'for confirmation. This does NOT book it — the customer '
                    'confirms on screen.',
            'parameters': {
              'type': 'object',
              'properties': {
                'business_id': {'type': 'string'},
                'day': {'type': 'string', 'enum': homeServiceDays},
                'slot': {'type': 'string', 'enum': homeServiceSlots},
                'hours': {
                  'type': 'integer',
                  'enum': [3, 4]
                },
                'address': {
                  'type': 'string',
                  'description': 'Where the work should happen.',
                },
              },
              'required': ['business_id', 'day', 'slot', 'hours', 'address'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'find_nearby_places',
            'description':
                'Search the public map for real places around the customer, '
                    'anywhere in the world — restaurants, street food, cafes, '
                    'grocery shops, hotels, pharmacies. Use this when '
                    'find_businesses has nothing suitable, or when the customer '
                    'is outside the area LocalHive covers, or when they ask '
                    'what is around them generally. '
                    'IMPORTANT: these are NOT LocalHive businesses. You can '
                    'name them, say what they serve and how far away they are, '
                    'and offer directions — but you CANNOT take an order or '
                    'make a booking at them, because they have no LocalHive '
                    'account to receive it. Say so honestly if asked.',
            'parameters': {
              'type': 'object',
              'properties': {
                'kind': {
                  'type': 'string',
                  'enum': [
                    'food',
                    'street_food',
                    'groceries',
                    'hotel',
                    'pharmacy'
                  ],
                },
                'query': {
                  'type': 'string',
                  'description':
                      'Optional keyword, e.g. a dish, cuisine or shop name.',
                },
              },
              'required': ['kind'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'list_my_orders',
            'description':
                "The customer's current orders and bookings with their status.",
            'parameters': {'type': 'object', 'properties': {}},
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'create_support_ticket',
            'description':
                'Raise a support request for a human to follow up. You MUST '
                    'call this before telling the customer that anyone will '
                    'contact them, and whenever they mention a refund, a '
                    'complaint, a missing or wrong order, a safety concern, or '
                    'ask to speak to a person. Never say a ticket has been '
                    'raised unless you called this.',
            'parameters': {
              'type': 'object',
              'properties': {
                'subject': {'type': 'string'},
                'details': {'type': 'string'},
              },
              'required': ['subject', 'details'],
            },
          },
        },
      ];

  // --------------------------------------------------------------- dispatch

  Future<Object> run(String name, Map<String, dynamic> args) async {
    try {
      if (name == 'create_support_ticket') raisedTicketThisTurn = true;
      switch (name) {
        case 'find_businesses':
          return await _findBusinesses(args);
        case 'get_menu':
          return _getMenu(args);
        case 'find_nearby_places':
          return await _findNearbyPlaces(args);
        case 'draft_order':
          return await _draftOrder(args);
        case 'draft_home_service':
          return await _draftHomeService(args);
        case 'list_my_orders':
          return _listMyOrders();
        case 'create_support_ticket':
          return await _createSupportTicket(args);
        default:
          return {'error': 'Unknown tool $name'};
      }
    } catch (e, st) {
      debugPrint('Olivia tool $name failed: $e\n$st');
      return {'error': 'That lookup failed. Tell the customer to try again.'};
    }
  }

  // ---------------------------------------------------------------- lookups

  /// Live listings first, falling back to the built-in catalog when Firestore
  /// has nothing. Listings with no owner are dropped: an order against one is
  /// written but no business owner can ever see it.
  Future<List<Provider>> _liveProviders(String category) async {
    final rows = await _fb.fetchProviders(category);
    final owned = rows
        .where((r) => r.$2.isNotEmpty)
        .map((r) => r.$1)
        .where((p) => p.name.isNotEmpty)
        .toList();
    if (owned.isNotEmpty) return owned;

    return switch (category) {
      'home_service' => homeServiceProviders,
      'indian_store' => indianStores,
      'food_truck' => foodTrucks,
      _ => const <Provider>[],
    };
  }

  Future<Map<String, dynamic>> _findBusinesses(
      Map<String, dynamic> args) async {
    final category = (args['category'] ?? '') as String;
    if (!_categories.contains(category)) {
      return {'error': 'category must be one of $_categories'};
    }
    final query = ((args['query'] ?? '') as String).toLowerCase().trim();
    final openNow = args['open_now'] == true;
    final now = DateTime.now();

    var list = await _liveProviders(category);

    if (query.isNotEmpty) {
      final terms = query.split(RegExp(r'\s+')).where((t) => t.length > 2);
      final matched = list.where((p) {
        final hay = '${p.name} ${p.subtitle} ${p.city}'.toLowerCase();
        return terms.any(hay.contains);
      }).toList();
      // A keyword that matches nothing shouldn't leave the customer with no
      // options at all — fall back to the full list rather than claiming
      // there is nothing nearby.
      if (matched.isNotEmpty) list = matched;
    }

    if (openNow) {
      final open =
          list.where((p) => isOpenAt(p.availableFrom, p.availableTo, now));
      if (open.isNotEmpty) list = open.toList();
    }

    final loc = LocationService.instance;
    final results = list.map((p) {
      double? km;
      if (loc.hasPosition && p.hasLocation) {
        km = distanceKm(loc.lat!, loc.lng!, p.lat, p.lng);
      }
      return (p, km);
    }).toList()
      ..sort((a, b) {
        if (a.$2 != null && b.$2 != null) return a.$2!.compareTo(b.$2!);
        if (a.$2 != null) return -1;
        if (b.$2 != null) return 1;
        return b.$1.rating.compareTo(a.$1.rating);
      });

    // LocalHive serves the USA. A customer whose location resolves elsewhere —
    // travelling, on a VPN, or via the coarse IP fallback — would otherwise be
    // handed a distance of several thousand kilometres, from which Olivia quite
    // reasonably concludes the marketplace is empty. Present the businesses
    // normally instead, and drop the meaningless distance.
    final nearest = results
        .map((r) => r.$2)
        .whereType<double>()
        .fold<double?>(null, (min, km) => min == null || km < min ? km : min);
    final outsideServiceArea = nearest != null && nearest > _serviceRadiusKm;

    return {
      'customer_area': loc.label,
      'count': results.length,
      'businesses': results.take(6).map((r) {
        final p = r.$1;
        return {
          'business_id': p.id,
          'name': p.name,
          'about': p.subtitle,
          'area': p.city,
          'rating': p.rating,
          'reviews': p.reviews,
          if (r.$2 != null && !outsideServiceArea)
            'distance': distanceLabel(r.$2!),
          if (p.availability.isNotEmpty) 'hours': p.availability,
          if (category == 'home_service') 'hourly_rate': p.hourlyRate,
        };
      }).toList(),
      if (outsideServiceArea)
        'service_area_note':
            "The customer's device places them outside the area LocalHive "
                'covers, so distances are not meaningful. These businesses are '
                'real and can take the order. Offer them normally and do not '
                'say there is nothing available.',
      if (results.isEmpty)
        'note': 'Nothing is listed in this category yet. Say so plainly and '
            'offer one of the other categories.',
    };
  }

  /// Beyond this, treat the customer's detected position as unusable rather
  /// than as evidence that nothing is nearby.
  static const _serviceRadiusKm = 300.0;

  /// Menus are per-category, not per-business: every store shares one grocery
  /// list and every truck one menu.
  List<CatalogItem> _menuFor(String category) => switch (category) {
        'indian_store' => storeCatalog,
        'food_truck' => truckMenu,
        _ => const <CatalogItem>[],
      };

  Future<Provider?> _providerById(String id) async {
    for (final category in _categories) {
      final list = await _liveProviders(category);
      for (final p in list) {
        if (p.id == id) return p;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _getMenu(Map<String, dynamic> args) async {
    final id = (args['business_id'] ?? '') as String;
    final provider = await _providerById(id);
    if (provider == null) {
      return {'error': 'No business with that id. Call find_businesses first.'};
    }
    if (provider.category == 'home_service') {
      return {
        'business': provider.name,
        'kind': 'home_service',
        'hourly_rate': provider.hourlyRate,
        'bookable_hours': [3, 4],
        'days': homeServiceDays,
        'start_times': homeServiceSlots,
        'note': 'Home services are booked by the hour, not from a menu.',
      };
    }
    final items = _menuFor(provider.category);
    return {
      'business': provider.name,
      'items': items
          .map((i) => {'name': i.name, 'price': i.price, 'unit': i.unit})
          .toList(),
    };
  }

  /// Real places from the public map, for when LocalHive has nothing suitable
  /// or the customer is outside the area it covers.
  Future<Map<String, dynamic>> _findNearbyPlaces(
      Map<String, dynamic> args) async {
    final loc = LocationService.instance;
    if (!loc.hasPosition) {
      return {
        'error': 'I do not know where the customer is yet.',
        'tell_customer':
            'Turn on location for LocalHive and I can look up what is around '
                'you.',
      };
    }
    final kind = (args['kind'] ?? 'food') as String;
    final places = await _places.search(
      lat: loc.lat!,
      lng: loc.lng!,
      kind: PlacesSearch.kinds.contains(kind) ? kind : 'food',
      query: args['query'] as String?,
    );
    if (places.isEmpty) {
      return {
        'area': loc.label,
        'count': 0,
        'note': 'The public map has nothing of that kind listed close by.',
      };
    }
    return {
      'area': loc.label,
      'count': places.length,
      'places': places.take(6).map((p) => p.toJson()).toList(),
      'source': 'OpenStreetMap — the public map, not LocalHive listings.',
      'ordering':
          'These are not LocalHive businesses, so you cannot place an order or '
              'take a booking at them. Describe them and offer directions only. '
              'If the customer wants to order through LocalHive, use '
              'find_businesses instead.',
    };
  }

  // ----------------------------------------------------------------- drafts

  /// Matches a spoken item to the menu. Speech gives "biryani", the menu says
  /// "Chicken Biryani", so exact matching is not enough.
  CatalogItem? _matchItem(List<CatalogItem> menu, String spoken) {
    final want = spoken.toLowerCase().trim();
    if (want.isEmpty) return null;

    for (final i in menu) {
      if (i.name.toLowerCase() == want) return i;
    }
    for (final i in menu) {
      final name = i.name.toLowerCase();
      if (name.contains(want) || want.contains(name)) return i;
    }
    // Fall back to the item sharing the most words with what was said.
    final wantWords =
        want.split(RegExp(r'[^a-z0-9]+')).where((w) => w.length > 2).toSet();
    if (wantWords.isEmpty) return null;
    CatalogItem? best;
    var bestScore = 0;
    for (final i in menu) {
      final itemWords = i.name
          .toLowerCase()
          .split(RegExp(r'[^a-z0-9]+'))
          .where((w) => w.length > 2)
          .toSet();
      final score = wantWords.intersection(itemWords).length;
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    return best;
  }

  Future<Map<String, dynamic>> _draftOrder(Map<String, dynamic> args) async {
    final id = (args['business_id'] ?? '') as String;
    final provider = await _providerById(id);
    if (provider == null) {
      return {'error': 'No business with that id. Call find_businesses first.'};
    }
    if (provider.category == 'home_service') {
      return {
        'error':
            'That is a home-service provider — use draft_home_service instead.'
      };
    }

    final menu = _menuFor(provider.category);
    final rawItems = (args['items'] as List?) ?? const [];
    final lines = <DraftLine>[];
    final unmatched = <String>[];

    for (final raw in rawItems) {
      final m = Map<String, dynamic>.from(raw as Map);
      final spoken = (m['name'] ?? '') as String;
      final qty = ((m['qty'] ?? 1) as num).toInt().clamp(1, 50);
      final item = _matchItem(menu, spoken);
      if (item == null) {
        unmatched.add(spoken);
        continue;
      }
      final existing = lines.indexWhere((l) => l.name == item.name);
      if (existing >= 0) {
        lines[existing] = DraftLine(
          name: item.name,
          qty: lines[existing].qty + qty,
          unitPrice: item.price,
          unit: item.unit,
          emoji: item.emoji,
        );
      } else {
        lines.add(DraftLine(
          name: item.name,
          qty: qty,
          unitPrice: item.price,
          unit: item.unit,
          emoji: item.emoji,
        ));
      }
    }

    if (lines.isEmpty) {
      return {
        'error': 'None of those items are on the menu.',
        'not_on_menu': unmatched,
        'available': menu.map((i) => i.name).toList(),
      };
    }

    final fulfillment =
        (args['fulfillment'] ?? 'pickup') == 'delivery' ? 'delivery' : 'pickup';
    final draft = OrderDraft(
      kind: 'order',
      providerId: provider.id,
      providerName: provider.name,
      category: provider.category,
      lines: lines,
      fulfillment: fulfillment,
      pickupEta: fulfillment == 'pickup'
          ? ((args['pickup_eta'] ?? 'In 30 min') as String)
          : '',
      address: fulfillment == 'delivery'
          ? ((args['address'] ?? '') as String).trim()
          : '',
      customerName: _app.userName ?? '',
      customerPhone: _app.userPhone ?? '',
      customerEmail: _app.userEmail ?? '',
    );
    pendingDraft = draft;

    return {
      ...draft.toJson(),
      if (unmatched.isNotEmpty) 'could_not_find': unmatched,
    };
  }

  Future<Map<String, dynamic>> _draftHomeService(
      Map<String, dynamic> args) async {
    final id = (args['business_id'] ?? '') as String;
    final provider = await _providerById(id);
    if (provider == null) {
      return {'error': 'No business with that id. Call find_businesses first.'};
    }
    if (provider.category != 'home_service') {
      return {'error': 'That business is not a home-service provider.'};
    }

    final hours = ((args['hours'] ?? 3) as num).toInt();
    final draft = OrderDraft(
      kind: 'home_service',
      providerId: provider.id,
      providerName: provider.name,
      category: 'home_service',
      dayLabel: homeServiceDays.contains(args['day'])
          ? args['day'] as String
          : 'Tomorrow',
      slot: homeServiceSlots.contains(args['slot'])
          ? args['slot'] as String
          : '10:00 AM',
      hours: hours == 4 ? 4 : 3,
      hourlyRate: provider.hourlyRate,
      address: ((args['address'] ?? '') as String).trim(),
      customerName: _app.userName ?? '',
      customerPhone: _app.userPhone ?? '',
      customerEmail: _app.userEmail ?? '',
    );
    pendingDraft = draft;
    return draft.toJson();
  }

  // ---------------------------------------------------------------- account

  Map<String, dynamic> _listMyOrders() {
    final bookings = _app.bookings;
    if (bookings.isEmpty) {
      return {'count': 0, 'orders': const [], 'note': 'Nothing ordered yet.'};
    }
    return {
      'count': bookings.length,
      'orders': bookings.take(10).map((b) {
        return {
          'business': b.providerName,
          'what': b.detail,
          'status': b.status,
          'total': b.amount,
          if (b.otp.isNotEmpty && b.status != 'Delivered')
            'delivery_code': b.otp,
          if (b.fulfillment.isNotEmpty) 'fulfillment': b.fulfillment,
        };
      }).toList(),
    };
  }

  Future<Map<String, dynamic>> _createSupportTicket(
      Map<String, dynamic> args) async {
    if (!_app.signedIn) {
      return {
        'error': 'The customer needs to sign in before raising a ticket.'
      };
    }
    final subject = ((args['subject'] ?? '') as String).trim();
    final details = ((args['details'] ?? '') as String).trim();
    if (subject.isEmpty) return {'error': 'A subject is required.'};

    final id =
        await _fb.createSupportTicket(subject: subject, details: details);
    if (id == null) {
      return {'error': 'Could not raise the ticket. Ask them to try again.'};
    }
    return {
      'ticket_id': id.substring(0, id.length < 6 ? id.length : 6),
      'status': 'open',
      'note': 'A person will follow up by email.',
    };
  }
}
