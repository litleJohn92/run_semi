import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Fond d'écran global : noir avec un halo violet en ellipse, centré sous le bas
/// de l'écran et qui s'estompe vers le haut.
/// Reprend le composant Figma "AppBackground glow" (node 18094:8588) : un cadre
/// de 390 × 675,2 px calé en bas d'un écran de 844 px.
/// Appliqué une seule fois via `MaterialApp.builder` dans main.dart.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  // Géométrie du dégradé Figma, en px dans le cadre 390 × 675,2.
  static const _frameW = 390.0;
  static const _frameH = 675.2;
  static const _centerX = 184.7; // légèrement à gauche du milieu (195)
  static const _centerY = 764.2; // 89 px sous le bas du cadre
  static const _radiusX = 271.3;
  static const _radiusY = 310.9;

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: AppTheme.bgApp),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          widthFactor: 1,
          heightFactor: _frameH / 844,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(2 * _centerX / _frameW - 1, 2 * _centerY / _frameH - 1),
                // Cercle de base = moitié du plus petit côté, remis à l'échelle
                // en ellipse par _Ellipse quelle que soit la taille de l'écran.
                radius: 0.5,
                colors: [AppTheme.bgGlow, AppTheme.bgGlowFade],
                transform: _Ellipse(
                  rx: _radiusX / _frameW,
                  ry: _radiusY / _frameH,
                  cx: _centerX / _frameW,
                  cy: _centerY / _frameH,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Transforme le cercle du dégradé radial en ellipse de rayons [rx]·largeur et
/// [ry]·hauteur, autour du centre ([cx], [cy]) exprimé en fraction du cadre.
class _Ellipse extends GradientTransform {
  final double rx, ry, cx, cy;
  const _Ellipse({required this.rx, required this.ry, required this.cx, required this.cy});

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final base = bounds.shortestSide / 2;
    final ox = bounds.left + cx * bounds.width;
    final oy = bounds.top + cy * bounds.height;
    return Matrix4.identity()
      ..translateByDouble(ox, oy, 0.0, 1.0)
      ..scaleByDouble(rx * bounds.width / base, ry * bounds.height / base, 1.0, 1.0)
      ..translateByDouble(-ox, -oy, 0.0, 1.0);
  }
}
