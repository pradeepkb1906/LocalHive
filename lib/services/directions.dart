import 'package:url_launcher/url_launcher.dart';
import '../models/data.dart';

/// Opens the user's own maps app (Google/Apple Maps) with directions to the
/// provider — no map API or key involved.
Future<void> openDirections(Provider p) async {
  final Uri uri;
  if (p.hasLocation) {
    uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}');
  } else {
    final q = Uri.encodeComponent('${p.name}, ${p.city}');
    uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
