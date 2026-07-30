import 'package:flutter/widgets.dart';

/// Non-web build: the raw HTML element does not exist here. Callers check
/// [webVideoSupported] and use video_player instead, so this view is never
/// actually built.
const bool webVideoSupported = false;

class WebVideoView extends StatelessWidget {
  final String assetPath;
  final bool playing;
  final String objectPosition;
  final String fit;

  const WebVideoView({
    super.key,
    required this.assetPath,
    required this.playing,
    this.objectPosition = '50% 50%',
    this.fit = 'cover',
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
