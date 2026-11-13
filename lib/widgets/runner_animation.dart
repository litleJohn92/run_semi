import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Cycle de course image par image, exporté du Figma (frame "Frame 76", node 18112:9401).
/// Les 11 frames sont empilées et seule la frame courante est peinte, pour
/// éviter tout clignotement au changement d'image.
class RunnerAnimation extends StatefulWidget {
  final double height;
  final Duration frameDuration;

  const RunnerAnimation({
    super.key,
    this.height = 80,
    this.frameDuration = const Duration(milliseconds: 80),
  });

  static const _frameCount = 11;
  static String _asset(int i) =>
      'assets/animations/run/run_${(i + 1).toString().padLeft(2, '0')}.svg';

  @override
  State<RunnerAnimation> createState() => _RunnerAnimationState();
}

class _RunnerAnimationState extends State<RunnerAnimation> {
  late final Timer _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.frameDuration, (_) {
      setState(() => _frame = (_frame + 1) % RunnerAnimation._frameCount);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // viewBox des SVG : 100 × 140
    return SizedBox(
      height: widget.height,
      width: widget.height * 100 / 140,
      child: Stack(children: [
        for (var i = 0; i < RunnerAnimation._frameCount; i++)
          Positioned.fill(
            child: Opacity(
              opacity: i == _frame ? 1 : 0,
              child: SvgPicture.asset(RunnerAnimation._asset(i)),
            ),
          ),
      ]),
    );
  }
}
