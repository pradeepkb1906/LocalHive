import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/data.dart';

/// Builds a Google Maps directions URL. Universal links work on every
/// platform: they open the Maps app on Android/iOS and maps.google.com in a
/// browser tab on desktop.
Uri directionsUri({double? lat, double? lng, String? query}) {
  if (lat != null && lng != null && (lat != 0 || lng != 0)) {
    return Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
  }
  return Uri.parse('https://www.google.com/maps/dir/?api=1'
      '&destination=${Uri.encodeComponent(query ?? '')}');
}

/// Opens turn-by-turn directions. Returns false when the browser blocked the
/// new tab (popup blocker) so callers can offer a fallback link.
Future<bool> _open(Uri uri) async {
  try {
    return await launchUrl(
      uri,
      // On web a new tab must be requested this way, or popup blockers win.
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  } catch (_) {
    return false;
  }
}

/// Directions to a listing (uses its coordinates when known).
Future<bool> openDirections(Provider p) =>
    _open(p.hasLocation
        ? directionsUri(lat: p.lat, lng: p.lng)
        : directionsUri(query: '${p.name}, ${p.city}'));

/// Directions to a street address — customer homes, delivery drop-offs.
Future<bool> openDirectionsToAddress(String address) =>
    _open(directionsUri(query: address));

/// Opens directions and, if the browser blocked the tab, shows the map link
/// so the user can still reach it.
Future<void> openDirectionsWithFallback(BuildContext context,
    {Provider? provider, String? address, double lat = 0, double lng = 0}) async {
  final uri = provider != null
      ? (provider.hasLocation
          ? directionsUri(lat: provider.lat, lng: provider.lng)
          : directionsUri(query: '${provider.name}, ${provider.city}'))
      : (lat != 0 || lng != 0)
          ? directionsUri(lat: lat, lng: lng)
          : directionsUri(query: address ?? '');
  final ok = await _open(uri);
  if (ok || !context.mounted) return;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Open directions'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Your browser blocked the map tab. Tap the link below to open '
              'directions in Google Maps.',
              style: TextStyle(fontSize: 13.5)),
          const SizedBox(height: 12),
          SelectableText(uri.toString(),
              style: const TextStyle(fontSize: 12.5, color: Colors.blue)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            launchUrl(uri, webOnlyWindowName: '_self');
          },
          child: const Text('Open Here'),
        ),
      ],
    ),
  );
}
