import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

/// Four-colour Google G, kept at its original 24 × 24 proportions.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Google',
    image: true,
    child: const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GooglePainter()),
    ),
  );
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();
  static final _parts = <(Color, Path)>[
    (
      const Color(0xFF4285F4),
      parseSvgPathData(
        'M21.6 12.23c0-.71-.06-1.39-.18-2.05H12v3.88h5.38a4.6 4.6 0 0 1-2 3.02v2.51h3.24c1.9-1.75 2.98-4.33 2.98-7.36z',
      ),
    ),
    (
      const Color(0xFF34A853),
      parseSvgPathData(
        'M12 22c2.7 0 4.96-.9 6.62-2.41l-3.24-2.51c-.9.6-2.04.96-3.38.96-2.6 0-4.81-1.76-5.6-4.12H3.06v2.59A10 10 0 0 0 12 22z',
      ),
    ),
    (
      const Color(0xFFFBBC05),
      parseSvgPathData(
        'M6.4 13.92a6 6 0 0 1 0-3.84V7.49H3.06a10 10 0 0 0 0 9.02z',
      ),
    ),
    (
      const Color(0xFFEA4335),
      parseSvgPathData(
        'M12 5.96c1.47 0 2.79.5 3.82 1.5l2.86-2.87A9.6 9.6 0 0 0 12 2a10 10 0 0 0-8.94 5.49l3.34 2.59C7.19 7.72 9.4 5.96 12 5.96z',
      ),
    ),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    for (final (color, path) in _parts) {
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}
