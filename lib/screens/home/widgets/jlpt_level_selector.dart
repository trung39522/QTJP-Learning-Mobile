import 'package:flutter/material.dart';

import '../../../core/theme/qtjp_colors.dart';

class JlptLevelSelector extends StatelessWidget {
  const JlptLevelSelector({
    required this.selectedLevel,
    required this.onSelected,
    super.key,
  });

  static const levels = ['N5', 'N4', 'N3', 'N2', 'N1'];

  final String selectedLevel;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: levels.map((level) {
            final active = selectedLevel == level;
            return Padding(
              padding: EdgeInsets.only(right: level == levels.last ? 0 : 8),
              child: SizedBox(
                width: ((constraints.maxWidth - 32) / 5).clamp(46.0, 80.0),
                child: ChoiceChip(
                  label: Center(child: Text(level)),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 9,
                  ),
                  selected: active,
                  onSelected: (_) => onSelected(level),
                  backgroundColor: context.qtjp.surface,
                  selectedColor: QTJPColors.navy,
                  labelStyle: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: active ? Colors.white : context.qtjp.heading,
                    fontWeight: FontWeight.w800,
                  ),
                  showCheckmark: false,
                  side: BorderSide(
                    color: active ? QTJPColors.navy : context.qtjp.border,
                  ),
                  tooltip: 'Chọn cấp độ $level',
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
