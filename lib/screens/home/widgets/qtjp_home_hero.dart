import 'package:flutter/material.dart';

import 'dart:math' as math;

import '../../../core/theme/qtjp_colors.dart';
import '../../../core/theme/qtjp_spacing.dart';

class QTJPHomeHero extends StatelessWidget {
  const QTJPHomeHero({
    required this.onPrimaryPressed,
    required this.onAlphabetPressed,
    required this.onFeaturePressed,
    super.key,
  });

  final VoidCallback onPrimaryPressed;
  final VoidCallback onAlphabetPressed;
  final ValueChanged<String> onFeaturePressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        return Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          padding: EdgeInsets.all(isWide ? QTJPSpacing.xxl : QTJPSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.qtjp.surface,
                context.qtjp.soft,
                context.qtjp.soft,
              ],
              stops: [0, 0.56, 1],
            ),
            border: Border.all(color: context.qtjp.border),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1206275B),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _HeroGridPainter()),
              ),
              const Positioned(
                right: -58,
                top: -72,
                child: _GlowCircle(size: 190, color: Color(0x173C7FBD)),
              ),
              const Positioned(
                left: -54,
                bottom: -72,
                child: _GlowCircle(size: 150, color: Color(0x12F32F36)),
              ),
              if (isWide)
                Row(
                  children: [
                    Expanded(
                      child: _HeroCopy(onPrimaryPressed, onAlphabetPressed),
                    ),
                    const SizedBox(width: 36),
                    Expanded(
                      child: _HeroVisual(onFeaturePressed: onFeaturePressed),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroCopy(onPrimaryPressed, onAlphabetPressed),
                    const SizedBox(height: 30),
                    Center(
                      child: _HeroVisual(onFeaturePressed: onFeaturePressed),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy(this.onPrimaryPressed, this.onAlphabetPressed);

  final VoidCallback onPrimaryPressed;
  final VoidCallback onAlphabetPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.qtjp.surface.withValues(alpha: 0.82),
            border: Border.all(color: const Color(0x1F06275B)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: QTJPColors.red,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 8),
              ),
              SizedBox(width: 9),
              Flexible(
                child: Text(
                  'QTJP LEARNING · HÀNH TRÌNH TIẾNG NHẬT',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.qtjp.heading,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text.rich(
          const TextSpan(
            children: [
              TextSpan(text: 'Học tiếng Nhật\n'),
              TextSpan(
                text: 'cùng QTJP',
                style: TextStyle(color: QTJPColors.red),
              ),
            ],
          ),
          style: TextStyle(
            color: context.qtjp.heading,
            fontSize: 39,
            height: 1.08,
            letterSpacing: -1.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Từ bảng chữ cái đến JLPT N1: học Flashcard, ngữ pháp, '
          'tra từ điển, luyện viết với AI, học qua video và thi thử — tất cả trên một nền tảng.',
          style: TextStyle(
            color: context.qtjp.muted,
            fontSize: 15,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final stackButtons = constraints.maxWidth < 390;
            final primary = FilledButton.icon(
              onPressed: onPrimaryPressed,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Bắt đầu học'),
            );
            final secondary = OutlinedButton(
              onPressed: onAlphabetPressed,
              child: const Text('Học bảng chữ cái'),
            );

            if (stackButtons) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [primary, const SizedBox(height: 10), secondary],
              );
            }

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [primary, secondary],
            );
          },
        ),
        const SizedBox(height: 22),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeroTag('Hiragana & Katakana'),
            _HeroTag('JLPT N5–N1'),
            _HeroTag('Flashcard'),
            _HeroTag('AI Writing'),
          ],
        ),
      ],
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.qtjp.surface.withValues(alpha: 0.78),
        border: Border.all(color: context.qtjp.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.qtjp.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeroVisual extends StatefulWidget {
  const _HeroVisual({required this.onFeaturePressed});

  final ValueChanged<String> onFeaturePressed;

  @override
  State<_HeroVisual> createState() => _HeroVisualState();
}

class _HeroVisualState extends State<_HeroVisual> {
  double _angle = 0;
  bool _dragging = false;

  static const _items = [
    ('dictionary', '辞', 'Từ điển', 'Tra Nhật – Việt'),
    ('flashcard', '単', 'Từ vựng', 'Học theo JLPT'),
    ('video', '映', 'Học qua video', 'Nghe & phân tích'),
    ('exam', '試', 'Thi thử JLPT', 'Đề thi & kết quả'),
    ('grammar', '文', 'Ngữ pháp', 'Mẫu câu & ví dụ'),
    ('writing', '書', 'Luyện viết AI', 'AI Sensei góp ý'),
    ('flashcard', '語', 'Flashcard', 'Lật thẻ từ vựng'),
  ];

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: AspectRatio(
        aspectRatio: 1,
        child: FittedBox(
          child: SizedBox.square(
            dimension: 360,
            child: GestureDetector(
              key: const ValueKey('home-feature-orbit'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => setState(() => _dragging = true),
              onHorizontalDragUpdate: (details) => setState(() {
                _angle += details.delta.dx / 120;
              }),
              onHorizontalDragEnd: (_) => setState(() => _dragging = false),
              onHorizontalDragCancel: () => setState(() => _dragging = false),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (final inset in [12.0, 44.0])
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.all(inset),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0x1A3C7FBD)),
                          ),
                        ),
                      ),
                    ),
                  Container(
                    width: 155,
                    height: 155,
                    decoration: BoxDecoration(
                      color: context.qtjp.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x2006275B),
                          blurRadius: 30,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: context.qtjp.pink,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '富士',
                                style: TextStyle(
                                  color: context.qtjp.heading,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'QTJP Learning',
                              style: TextStyle(
                                color: context.qtjp.heading,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'JAPANESE LEARNING',
                              style: TextStyle(
                                color: context.qtjp.blue,
                                fontSize: 7,
                                letterSpacing: 1.2,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Xoay vòng chức năng',
                              onPressed: () => setState(
                                () => _angle += 2 * math.pi / _items.length,
                              ),
                              icon: Icon(
                                Icons.rotate_right_rounded,
                                color: context.qtjp.blue,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  for (var index = 0; index < _items.length; index++)
                    TweenAnimationBuilder<double>(
                      key: ValueKey('orbit-slot-$index'),
                      tween: Tween(end: _angle),
                      duration:
                          _dragging || MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 350),
                      builder: (context, angle, child) {
                        final position =
                            angle -
                            math.pi / 2 +
                            index * 2 * math.pi / _items.length;
                        return Positioned(
                          left: 130 + 128 * math.cos(position),
                          top: 158 + 148 * math.sin(position),
                          width: 100,
                          height: 44,
                          child: child!,
                        );
                      },
                      child: _OrbitLabel(
                        symbol: _items[index].$2,
                        label: _items[index].$3,
                        detail: _items[index].$4,
                        onPressed: () =>
                            widget.onFeaturePressed(_items[index].$1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitLabel extends StatelessWidget {
  const _OrbitLabel({
    required this.symbol,
    required this.label,
    required this.detail,
    required this.onPressed,
  });

  final String symbol;
  final String label;
  final String detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1406275B),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: context.qtjp.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 25,
                  height: 25,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: QTJPColors.navy,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: context.qtjp.heading,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          detail,
                          style: TextStyle(
                            color: context.qtjp.muted,
                            fontSize: 6.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _HeroGridPainter extends CustomPainter {
  const _HeroGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x073C7FBD)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_HeroGridPainter oldDelegate) => false;
}
