import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/atlas_theme.dart';

class LaunchSplashScreen extends StatefulWidget {
  const LaunchSplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<LaunchSplashScreen> createState() => _LaunchSplashScreenState();
}

class _LaunchSplashScreenState extends State<LaunchSplashScreen> {
  Timer? _timer;
  var _completed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), _complete);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _complete() {
    if (_completed || !mounted) return;
    _completed = true;
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Skip splash screen',
      child: GestureDetector(
        key: const ValueKey('launch-splash'),
        behavior: HitTestBehavior.opaque,
        onTap: _complete,
        child: Scaffold(
          backgroundColor: AtlasTheme.background,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: SizedBox(
                  width: 390,
                  child: AspectRatio(
                    aspectRatio: 390 / 280,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SvgPicture.asset(
                          'assets/illustrations/cultural_seals_splash.svg',
                          key: const ValueKey('splash-illustration'),
                        ),
                        Align(
                          alignment: const Alignment(0, -0.32),
                          child: Text(
                            'KJC 7-Day Trip',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: AtlasTheme.heading,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
