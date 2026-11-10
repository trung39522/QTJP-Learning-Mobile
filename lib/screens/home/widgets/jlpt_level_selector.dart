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
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: levels.map((level) {
        final active = selectedLevel == level;
        return ChoiceChip(
          label: Text(level),
          selected: active,
          onSelected: (_) => onSelected(level),
          backgroundColor: QTJPColors.surface,
          selectedColor: QTJPColors.navy,
          labelStyle: TextStyle(
            color: active ? Colors.white : QTJPColors.navy,
            fontWeight: FontWeight.w800,
          ),
          showCheckmark: false,
          side: BorderSide(color: active ? QTJPColors.navy : QTJPColors.border),
          tooltip: 'Chọn cấp độ $level',
        );
      }).toList(),
    );
  }
}
