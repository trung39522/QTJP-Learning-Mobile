import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/qtjp_colors.dart';

Color examSkillColor(String category, {bool dark = false}) {
  const palette = {
    'KANJI': Color(0xFF4778BF),
    'VOCAB': Color(0xFF23877D),
    'GRAMMAR': Color(0xFF8471B4),
    'READING': Color(0xFFB58328),
    'LISTENING': Color(0xFFBB617F),
  };
  final color = palette[category] ?? QTJPColors.blue;
  return dark ? Color.lerp(color, Colors.white, .22)! : color;
}

class ExamSkillChart extends StatelessWidget {
  const ExamSkillChart({
    required this.categories,
    required this.labels,
    super.key,
  });
  final List<Map<String, dynamic>> categories;
  final Map<String, String> labels;
  double _value(Map<String, dynamic> c) =>
      ((c['percent'] is num
                  ? (c['percent'] as num).toDouble()
                  : double.tryParse('${c['percent']}')) ??
              0)
          .clamp(0, 100);
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Semantics(
          image: true,
          label:
              'Biểu đồ tỷ lệ đúng: ${categories.map((c) => '${labels[c['category']] ?? c['category']} ${_value(c).toStringAsFixed(1)} phần trăm').join(', ')}',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              const height = 270.0;
              final radius = math.min(width * .27, 78.0);
              final center = Offset(width / 2, height / 2);
              final values = categories.map((c) => _value(c) / 100).toList();
              final colors = categories
                  .map((c) => examSkillColor('${c['category']}', dark: dark))
                  .toList();
              return SizedBox(
                height: height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SkillRadarPainter(
                          values,
                          colors,
                          context.qtjp.border,
                          context.qtjp.muted,
                          radius,
                        ),
                      ),
                    ),
                    for (var i = 0; i < categories.length; i++)
                      Builder(
                        builder: (context) {
                          final angle =
                              -math.pi / 2 +
                              i * 2 * math.pi / categories.length;
                          final position =
                              center +
                              Offset(math.cos(angle), math.sin(angle)) *
                                  (radius + 37);
                          const labelWidth = 80.0;
                          return Positioned(
                            left: (position.dx - labelWidth / 2).clamp(
                              0,
                              width - labelWidth,
                            ),
                            top: (position.dy - 23).clamp(0, height - 54),
                            width: labelWidth,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  labels[categories[i]['category']] ??
                                      '${categories[i]['category']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: context.qtjp.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_value(categories[i]).toStringAsFixed(0)}%',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors[i],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        Text(
          'Thang 0–100% · Tỷ lệ trả lời đúng theo kỹ năng',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.qtjp.muted,
            fontSize: 10,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SkillRadarPainter extends CustomPainter {
  const _SkillRadarPainter(
    this.values,
    this.colors,
    this.grid,
    this.muted,
    this.radius,
  );
  final List<double> values;
  final List<Color> colors;
  final Color grid, muted;
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    Offset point(int i, double value) {
      final a = -math.pi / 2 + i * 2 * math.pi / values.length;
      return center + Offset(math.cos(a), math.sin(a)) * radius * value;
    }

    Path polygon(List<double> points) {
      final p = Path()..moveTo(point(0, points[0]).dx, point(0, points[0]).dy);
      for (var i = 1; i < points.length; i++) {
        final o = point(i, points[i]);
        p.lineTo(o.dx, o.dy);
      }
      return p..close();
    }

    for (var level = 1; level <= 4; level++) {
      canvas.drawPath(
        polygon(List.filled(values.length, level / 4)),
        Paint()
          ..color = grid
          ..strokeWidth = (level == 4 ? 1.2 : .7)
          ..style = PaintingStyle.stroke,
      );
    }
    for (var i = 0; i < values.length; i++) {
      canvas.drawLine(
        center,
        point(i, 1),
        Paint()
          ..color = grid
          ..strokeWidth = .7,
      );
    }
    final shape = polygon(values);
    canvas.drawPath(
      shape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66339F94), Color(0x154778BF)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..color = const Color(0xFF338E86)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(point(i, values[i]), 4, Paint()..color = colors[i]);
      canvas.drawCircle(
        point(i, values[i]),
        4,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
    final tick = TextPainter(
      text: TextSpan(
        text: '50',
        style: TextStyle(color: muted, fontSize: 8, fontFamily: 'Roboto'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tick.paint(canvas, center + Offset(4, -radius * .5 - tick.height));
  }

  @override
  bool shouldRepaint(_SkillRadarPainter oldDelegate) =>
      !listEquals(values, oldDelegate.values) ||
      !listEquals(colors, oldDelegate.colors) ||
      grid != oldDelegate.grid ||
      muted != oldDelegate.muted ||
      radius != oldDelegate.radius;
}
