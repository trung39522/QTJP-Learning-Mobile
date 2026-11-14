import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../core/theme/qtjp_colors.dart';
import '../data/kana_stroke_repository.dart';

class KanaStrokeViewer extends StatefulWidget {
  const KanaStrokeViewer({required this.glyphs, super.key});

  final List<KanaGlyph> glyphs;

  @override
  State<KanaStrokeViewer> createState() => _KanaStrokeViewerState();
}

class _KanaStrokeViewerState extends State<KanaStrokeViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<List<_Stroke>> _strokes;
  late final int _total;
  bool _reducedMotion = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _strokes = widget.glyphs
        .map(
          (glyph) => glyph.paths.map((source) {
            final path = parseSvgPathData(source);
            return _Stroke(path, path.computeMetrics().toList());
          }).toList(),
        )
        .toList();
    _total = _strokes.fold(0, (sum, glyph) => sum + glyph.length);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _total * 650 + 300),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _controller.value = 1;
    } else if (!_started) {
      _controller.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          image: true,
          label:
              'Thứ tự $_total nét của ${widget.glyphs.map((glyph) => glyph.character).join()}',
          child: Container(
            constraints: const BoxConstraints(maxWidth: 430),
            decoration: BoxDecoration(
              color: context.qtjp.surface,
              border: Border.all(color: context.qtjp.border),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(10),
            child: AspectRatio(
              aspectRatio: widget.glyphs.length.toDouble(),
              child: CustomPaint(
                painter: _StrokePainter(
                  palette: context.qtjp,
                  glyphs: widget.glyphs,
                  strokes: _strokes,
                  total: _total,
                  animation: _controller,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$_total nét · Theo dõi nét màu đỏ và số thứ tự',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.qtjp.muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              TextButton.icon(
                key: const ValueKey('kana-stroke-replay'),
                onPressed: _reducedMotion
                    ? null
                    : () => _controller.forward(from: 0),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Xem lại nét viết'),
              ),
              TextButton.icon(
                onPressed: _reducedMotion || _controller.isCompleted
                    ? null
                    : () {
                        if (_controller.isAnimating) {
                          _controller.stop();
                        } else {
                          _controller.forward();
                        }
                        setState(() {});
                      },
                icon: Icon(
                  _controller.isAnimating
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(_controller.isAnimating ? 'Tạm dừng' : 'Tiếp tục'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stroke {
  _Stroke(this.path, this.metrics);

  final Path path;
  final List<ui.PathMetric> metrics;
}

class _StrokePainter extends CustomPainter {
  _StrokePainter({
    required this.palette,
    required this.glyphs,
    required this.strokes,
    required this.total,
    required this.animation,
  }) : super(repaint: animation);

  final List<KanaGlyph> glyphs;
  final List<List<_Stroke>> strokes;
  final int total;
  final Animation<double> animation;
  final QTJPColorPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / (109 * glyphs.length),
      size.height / 109,
    );
    canvas.save();
    canvas.translate(
      (size.width - 109 * glyphs.length * scale) / 2,
      (size.height - 109 * scale) / 2,
    );
    canvas.scale(scale);
    var strokeIndex = 0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final guide = Paint()
      ..color = palette.border
      ..strokeWidth = 0.6;
    for (var glyphIndex = 0; glyphIndex < glyphs.length; glyphIndex++) {
      canvas.save();
      canvas.translate(glyphIndex * 109.0, 0);
      for (var offset = 7.0; offset < 102; offset += 7) {
        canvas.drawLine(Offset(54.5, offset), Offset(54.5, offset + 3), guide);
        canvas.drawLine(Offset(offset, 54.5), Offset(offset + 3, 54.5), guide);
      }
      for (final stroke in strokes[glyphIndex]) {
        canvas.drawPath(stroke.path, paint..color = palette.border);
      }
      for (final stroke in strokes[glyphIndex]) {
        final fraction = (animation.value * (total + 0.4) - strokeIndex).clamp(
          0.0,
          1.0,
        );
        if (fraction > 0) {
          paint.color = fraction < 1 ? QTJPColors.red : palette.heading;
          var remaining =
              stroke.metrics.fold(0.0, (sum, metric) => sum + metric.length) *
              fraction;
          for (final metric in stroke.metrics) {
            if (remaining <= 0) break;
            canvas.drawPath(
              metric.extractPath(0, math.min(remaining, metric.length)),
              paint,
            );
            remaining -= metric.length;
          }
        }
        strokeIndex++;
      }
      for (final number in glyphs[glyphIndex].numbers) {
        final label = TextPainter(
          text: TextSpan(
            text: number.text,
            style: TextStyle(
              color: palette.blue,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(number.x, number.y - 8));
        label.dispose();
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.animation != animation ||
      oldDelegate.palette != palette;
}
