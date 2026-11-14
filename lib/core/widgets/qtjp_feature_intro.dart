import 'package:flutter/material.dart';

import '../theme/qtjp_colors.dart';

enum QTJPFeature { dictionary, flashcard, grammar, alphabet, writing, exam }

/// Mobile composition of the corresponding React page's heading and artwork.
/// Photography is copied unchanged from the website's public assets.
class QTJPFeatureIntro extends StatelessWidget {
  const QTJPFeatureIntro(this.feature, {super.key});
  final QTJPFeature feature;

  static const _copy = {
    QTJPFeature.dictionary: (
      'NIHONGO DICTIONARY',
      'Tra cứu Từ điển Nhật – Việt',
      'Kho dữ liệu đa cấp độ N5–N1, ngữ cảnh thực tế và từ liên quan.',
    ),
    QTJPFeature.flashcard: (
      'FLASHCARD JLPT',
      'Học Từ Vựng Tiếng Nhật',
      'Chọn cấp độ phù hợp và học theo từng chủ đề để ghi nhớ từ vựng hiệu quả hơn.',
    ),
    QTJPFeature.grammar: (
      'NGỮ PHÁP',
      'Học và phân tích ngữ pháp tiếng Nhật',
      'Học theo giáo trình, tra cứu mẫu ngữ pháp và phân tích câu tiếng Nhật — tất cả trong một nơi.',
    ),
    QTJPFeature.alphabet: (
      'JAPANESE ALPHABET',
      'Bảng chữ cái tiếng Nhật',
      'Chạm vào mỗi chữ để xem thứ tự nét viết và nghe âm đọc.',
    ),
    QTJPFeature.writing: (
      'AI WRITING SENSEI',
      'Luyện Viết Tiếng Nhật cùng AI',
      'Viết bài, nhận phản hồi chi tiết, tự sửa lại và theo dõi tiến bộ theo từng cấp độ JLPT.',
    ),
    QTJPFeature.exam: (
      'QTJP LEARNING · PHÒNG HỌC JLPT',
      'Thi thử JLPT',
      'Bước vào lớp học Nhật Bản, chọn đề phù hợp và luyện tập theo từng phần.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (eyebrow, title, description) = _copy[feature]!;
    final photo = switch (feature) {
      QTJPFeature.writing => 'assets/learning/writing2.jpg',
      QTJPFeature.exam => 'assets/learning/jlpt-classroom.jpg',
      _ => null,
    };
    return Container(
      key: ValueKey('feature-intro-${feature.name}'),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: context.qtjp.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.qtjp.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photo != null)
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 7,
                  child: Image.asset(
                    photo,
                    fit: BoxFit.cover,
                    cacheWidth: 1000,
                    semanticLabel: feature == QTJPFeature.writing
                        ? 'Góc bàn học cạnh cửa sổ với vở viết và sách tiếng Nhật'
                        : 'Phòng học Nhật Bản với bàn ghế gỗ và bảng xanh',
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          QTJPColors.navy.withValues(alpha: .7),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Text(
                    feature == QTJPFeature.writing
                        ? 'Mỗi ngày viết một chút.'
                        : '日本語能力試験 · JLPT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          CustomPaint(
            painter: _IntroArt(feature),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.qtjp.pink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      eyebrow,
                      style: const TextStyle(
                        color: QTJPColors.red,
                        fontSize: 10,
                        height: 1.5,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: context.qtjp.heading,
                      fontSize: 25,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (feature != QTJPFeature.flashcard &&
                      feature != QTJPFeature.grammar) ...[
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: TextStyle(
                        color: context.qtjp.muted,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroArt extends CustomPainter {
  const _IntroArt(this.feature);
  final QTJPFeature feature;
  @override
  void paint(Canvas canvas, Size size) {
    if (feature == QTJPFeature.grammar) {
      // The React artwork uses CSS polygons for Fuji and a soft red sun.
      canvas.drawCircle(
        Offset(size.width - 32, 35),
        24,
        Paint()..color = const Color(0x15F45B67),
      );
      canvas.drawPath(
        Path()
          ..moveTo(size.width - 140, size.height)
          ..lineTo(size.width - 60, 52)
          ..lineTo(size.width + 30, size.height)
          ..close(),
        Paint()..color = const Color(0x25BDD4EE),
      );
      canvas.drawPath(
        Path()
          ..moveTo(size.width - 88, 87)
          ..lineTo(size.width - 60, 52)
          ..lineTo(size.width - 29, 88)
          ..lineTo(size.width - 52, 81)
          ..lineTo(size.width - 64, 90)
          ..close(),
        Paint()..color = const Color(0xB0FFFFFF),
      );
    } else if (feature == QTJPFeature.dictionary) {
      final paint = Paint()..color = const Color(0x18EEA2B7);
      for (final offset in [
        const Offset(-24, 20),
        const Offset(-52, 58),
        const Offset(-13, 94),
      ]) {
        final center = Offset(size.width + offset.dx, offset.dy);
        for (final point in [
          const Offset(0, -6),
          const Offset(6, 0),
          const Offset(3, 6),
          const Offset(-5, 5),
          const Offset(-6, -2),
        ]) {
          canvas.drawOval(
            Rect.fromCenter(center: center + point, width: 9, height: 12),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_IntroArt oldDelegate) => feature != oldDelegate.feature;
}
