import 'package:flutter/material.dart';

import '../../../core/theme/qtjp_colors.dart';
import '../vocabulary_practice_screen.dart';

class FlashcardWorkspace extends StatelessWidget {
  const FlashcardWorkspace({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF0B182B), Color(0xFF12233A)]
              : const [Color(0xFFE2F0FB), Color(0xFFF2F7FD)],
        ),
      ),
      child: CustomPaint(painter: _StudyGrid(dark), child: child),
    );
  }
}

class _StudyGrid extends CustomPainter {
  const _StudyGrid(this.dark);
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? const Color(0xFF88B9E8) : QTJPColors.blue).withValues(
        alpha: dark ? .05 : .07,
      )
      ..strokeWidth = .6;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_StudyGrid oldDelegate) => dark != oldDelegate.dark;
}

class FlashcardModeBar extends StatelessWidget {
  const FlashcardModeBar({
    required this.onSelected,
    this.enabled = true,
    super.key,
  });
  final ValueChanged<VocabularyMode> onSelected;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.qtjp.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.qtjp.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'CHỌN CHẾ ĐỘ HỌC',
          style: TextStyle(
            color: context.qtjp.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: QTJPColors.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Flashcard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final entry in {
                VocabularyMode.quiz: 'Trắc nghiệm',
                VocabularyMode.listening: 'Nghe chọn',
                VocabularyMode.typing: 'Gõ chữ',
                VocabularyMode.fill: 'Điền từ',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: OutlinedButton(
                    key: ValueKey('study-mode-${entry.key.name}'),
                    onPressed: enabled ? () => onSelected(entry.key) : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    child: Text(entry.value),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
