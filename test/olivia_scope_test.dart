import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/services/olivia/olivia_tools.dart';

// Olivia is a grocery assistant. Her tool surface is the contract: if a tool
// for restaurants, food trucks or home services ever reappears here, she can
// be talked into using it — so the surface itself is what gets pinned.
void main() {
  List<String> toolNames() => OliviaTools.schemas
      .map((s) => '${(s['function'] as Map)['name']}')
      .toList();

  String allSchemaText() => OliviaTools.schemas.toString().toLowerCase();

  test('her tools are exactly the grocery set', () {
    expect(
        toolNames()..sort(),
        [
          'create_support_ticket',
          'draft_order',
          'find_nearby_stores',
          'find_stores',
          'get_menu',
          'list_my_orders',
          'offer_call',
        ]..sort());
  });

  test('no tool exists for the retired verticals', () {
    for (final gone in [
      'find_businesses',
      'find_nearby_places',
      'draft_home_service',
    ]) {
      expect(toolNames(), isNot(contains(gone)),
          reason: '$gone belongs to a vertical LocalHive no longer runs');
    }
  });

  test('the map search is fixed to grocery shops', () {
    final nearby = OliviaTools.schemas.firstWhere(
        (s) => (s['function'] as Map)['name'] == 'find_nearby_stores');
    final params =
        ((nearby['function'] as Map)['parameters'] as Map)['properties'] as Map;
    // No `kind` argument at all: the model cannot steer her to restaurants.
    expect(params.containsKey('kind'), isFalse);
    expect(params.keys, containsAll(['query', 'radius_km']));
  });

  test('ordering is limited to partner grocery stores', () {
    final find = OliviaTools.schemas
        .firstWhere((s) => (s['function'] as Map)['name'] == 'find_stores');
    final params =
        ((find['function'] as Map)['parameters'] as Map)['properties'] as Map;
    // No category argument — there is only one category left.
    expect(params.containsKey('category'), isFalse);
    // The retired verticals may appear only as things she refuses, never as
    // something a tool offers to do.
    final text = allSchemaText();
    for (final word in ['food truck', 'restaurant', 'handyman']) {
      if (!text.contains(word)) continue;
      expect(text.contains('outside') || text.contains('only covers grocery'),
          isTrue,
          reason: '"$word" appears without exclusion wording around it');
    }
  });
}
