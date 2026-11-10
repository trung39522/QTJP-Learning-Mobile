import 'package:flutter/material.dart';

import '../../../core/theme/qtjp_colors.dart';
import '../../../core/theme/qtjp_spacing.dart';

class QTJPHomeHero extends StatelessWidget {
  const QTJPHomeHero({
    required this.onPrimaryPressed,
    required this.onAlphabetPressed,
    super.key,
  });

  final VoidCallback onPrimaryPressed;
  final VoidCallback onAlphabetPressed;

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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF5F9FD), Color(0xFFEDF5FC)],
              stops: [0, 0.56, 1],
            ),
            border: Border.all(color: const Color(0xFFDCE8F3)),
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
                    const Expanded(child: _HeroVisual()),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroCopy(onPrimaryPressed, onAlphabetPressed),
                    const SizedBox(height: 30),
                    const Center(child: _HeroVisual()),
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
            color: Colors.white.withValues(alpha: 0.82),
            border: Border.all(color: const Color(0x1F06275B)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
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
                    color: QTJPColors.navy,
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
          style: const TextStyle(
            color: QTJPColors.navyDark,
            fontSize: 39,
            height: 1.08,
            letterSpacing: -1.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Từ bảng chữ cái đến JLPT N1: học Flashcard, ngữ pháp, '
          'tra từ điển, luyện viết với AI và thi thử trên cùng một nền tảng.',
          style: TextStyle(color: QTJPColors.muted, fontSize: 15, height: 1.65),
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
        color: Colors.white.withValues(alpha: 0.78),
        border: Border.all(color: QTJPColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: QTJPColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 310),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0x2606275B)),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0x2206275B),
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 154,
              height: 154,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x2606275B),
                    blurRadius: 30,
                    offset: Offset(0, 13),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: CustomPaint(painter: _FujiPainter()),
              ),
            ),
            const Positioned(
              top: 2,
              left: 12,
              child: _OrbitLabel(symbol: '語', label: 'Flashcard'),
            ),
            const Positioned(
              top: 37,
              right: 0,
              child: _OrbitLabel(symbol: '文', label: 'Ngữ pháp'),
            ),
            const Positioned(
              bottom: 19,
              right: 17,
              child: _OrbitLabel(symbol: '試', label: 'JLPT'),
            ),
            const Positioned(
              bottom: 38,
              left: 0,
              child: _OrbitLabel(symbol: '辞', label: 'Từ điển'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbitLabel extends StatelessWidget {
  const _OrbitLabel({required this.symbol, required this.label});

  final String symbol;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x2406275B)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1406275B),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 27,
            height: 27,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: QTJPColors.softBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              symbol,
              style: const TextStyle(
                color: QTJPColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: QTJPColors.navy,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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

class _FujiPainter extends CustomPainter {
  const _FujiPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sunPaint = Paint()..color = QTJPColors.red.withValues(alpha: 0.14);
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.3),
      size.shortestSide * 0.2,
      sunPaint,
    );

    final mountain = Path()
      ..moveTo(size.width * 0.08, size.height * 0.74)
      ..lineTo(size.width * 0.5, size.height * 0.27)
      ..lineTo(size.width * 0.92, size.height * 0.74)
      ..close();
    canvas.drawPath(
      mountain,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [QTJPColors.blue, QTJPColors.navy],
        ).createShader(Offset.zero & size),
    );

    final snow = Path()
      ..moveTo(size.width * 0.5, size.height * 0.27)
      ..lineTo(size.width * 0.35, size.height * 0.44)
      ..lineTo(size.width * 0.44, size.height * 0.41)
      ..lineTo(size.width * 0.5, size.height * 0.5)
      ..lineTo(size.width * 0.57, size.height * 0.4)
      ..lineTo(size.width * 0.66, size.height * 0.45)
      ..close();
    canvas.drawPath(snow, Paint()..color = Colors.white);

    final ground = Paint()
      ..color = QTJPColors.blue.withValues(alpha: 0.26)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.04, size.height * 0.77),
      Offset(size.width * 0.96, size.height * 0.77),
      ground,
    );

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'QTJP',
        style: TextStyle(
          color: QTJPColors.navy,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height * 0.82),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
