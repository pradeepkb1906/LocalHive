import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/data.dart';
import '../supabase_config.dart';

/// A read-only standby copy of the public store catalog, held in Supabase.
///
/// Firestore is the system of record: every write goes there and nothing is
/// written here from the app. This exists for the day Firestore cannot be
/// read — an outage, or the free tier's daily read quota running out, which
/// has already happened once and took the catalog down for a full day. When
/// that happens the app falls back to this mirror so customers can still see
/// which stores exist, their hours and their phone numbers. Ordering stays
/// unavailable, and the UI says so rather than pretending.
///
/// Deliberately plain HTTP against Supabase's REST endpoint rather than the
/// Supabase SDK: one fewer dependency, no extra weight in the web bundle,
/// and a standby path with fewer moving parts than the thing it is standing
/// in for.
class SupabaseMirror {
  SupabaseMirror._();
  static final SupabaseMirror instance = SupabaseMirror._();

  /// Overridable so tests never touch the network.
  @visibleForTesting
  http.Client client = http.Client();

  bool get enabled => SupabaseConfig.enabled;

  /// True once a read has actually fallen through to the mirror, so screens
  /// can tell the customer what they are looking at.
  bool servingFromMirror = false;

  Map<String, String> get _headers => {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
      };

  /// Live listings of [category] from the mirror, nearest-agnostic and
  /// ordered by name. Returns null when the mirror is switched off or itself
  /// unreachable — the caller then has nothing to show, which is the honest
  /// outcome when both backends are down.
  Future<List<Provider>?> providers(String category) async {
    if (!enabled) return null;
    try {
      final uri = Uri.parse('${SupabaseConfig.url}/rest/v1/providers'
          '?select=*&live=eq.true&category=eq.$category&order=name');
      final resp = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        debugPrint('Supabase mirror returned ${resp.statusCode}');
        return null;
      }
      final rows = jsonDecode(resp.body) as List;
      final list = rows
          .whereType<Map<String, dynamic>>()
          .map(providerFromMirrorRow)
          .where((p) => p.name.isNotEmpty)
          .toList();
      servingFromMirror = true;
      return list;
    } catch (e) {
      debugPrint('Supabase mirror unreachable: $e');
      return null;
    }
  }

  /// A quick liveness probe, for the System check screen.
  Future<bool> reachable() async {
    if (!enabled) return false;
    try {
      final uri = Uri.parse(
          '${SupabaseConfig.url}/rest/v1/providers?select=id&limit=1');
      final resp = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

/// Maps one mirrored row onto the app's [Provider]. Column names match the
/// Firestore field names so the sync script is a straight copy.
Provider providerFromMirrorRow(Map<String, dynamic> m) => Provider(
      id: '${m['id'] ?? ''}',
      name: '${m['name'] ?? ''}',
      category: '${m['category'] ?? ''}',
      subtitle: '${m['subtitle'] ?? ''}',
      rating: (m['rating'] as num?)?.toDouble() ?? 0,
      reviews: (m['reviews'] as num?)?.toInt() ?? 0,
      hourlyRate: (m['hourly_rate'] as num?)?.toDouble() ?? 0,
      city: '${m['city'] ?? ''}',
      verified: m['verified'] == true,
      emoji: '${m['emoji'] ?? ''}',
      lat: (m['lat'] as num?)?.toDouble() ?? 0,
      lng: (m['lng'] as num?)?.toDouble() ?? 0,
      availableFrom: '${m['available_from'] ?? ''}',
      availableTo: '${m['available_to'] ?? ''}',
    );
