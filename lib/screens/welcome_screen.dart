import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme.dart';
import 'profile_screen.dart';

/// The first thing anyone sees: the LocalHive brand film, full screen, with
/// one button. Tapping Sign In opens the sign-in page (demo accounts and all);
/// once signed in, the root gate swaps straight into the app.
///
/// If the film cannot play — an old browser, a saving-data mode — the same
/// frame stands still behind the button, so the screen never looks broken.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const _clip = 'assets/brand/signin.mp4';
  static const _poster = 'assets/brand/signin.png';
  static const _clipSize = Size(464, 688);

  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final controller = VideoPlayerController.asset(_clip);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _video = controller);
      // Muted autoplay is allowed everywhere; a refusal just leaves the
      // poster showing, which is this same film's own frame.
      await controller.play();
    } catch (e) {
      debugPrint('Welcome film unavailable, using the still: $e');
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;

    return Scaffold(
      backgroundColor: LhColors.navy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The film (or its still), covering the whole screen. Cover is done
          // by sizing and clipping, not scaling: a video is a platform view on
          // the web and a scaled platform view paints nothing.
          LayoutBuilder(
            builder: (context, box) {
              final scale = math.max(
                box.maxWidth / _clipSize.width,
                box.maxHeight / _clipSize.height,
              );
              final w = _clipSize.width * scale;
              final h = _clipSize.height * scale;
              final child = (video != null && video.value.isInitialized)
                  ? VideoPlayer(video)
                  : Image.asset(_poster, fit: BoxFit.cover);
              return ClipRect(
                child: OverflowBox(
                  maxWidth: w,
                  maxHeight: h,
                  child: SizedBox(width: w, height: h, child: child),
                ),
              );
            },
          ),
          // A quiet gradient so the button reads on any frame of the film.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.55, 1.0],
                colors: [Color(0x00000000), Color(0x99000000)],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Local services, stores & food trucks — one app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: LhColors.navy,
                          textStyle: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SignInScreen()),
                        ),
                        child: const Text('Sign In'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
