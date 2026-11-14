import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../../core/theme/qtjp_colors.dart';
import '../home/models/home_feature_item.dart';
import '../home/widgets/jlpt_level_selector.dart';

/// The entry screen for each study area, before learning content is connected.
class FeatureScreen extends StatelessWidget {
  const FeatureScreen({
    required this.feature,
    required this.selectedLevel,
    this.onLevelChanged,
    super.key,
  });

  final HomeFeatureItem feature;
  final String selectedLevel;
  final ValueChanged<String>? onLevelChanged;

  @override
  Widget build(BuildContext context) {
    final accent = feature.accent == HomeFeatureAccent.red
        ? QTJPColors.red
        : QTJPColors.blue;

    return KyutoScaffold(
      appBar: AppBar(title: Text(feature.title)),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: accent.withValues(alpha: 0.16)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.symbol,
                          style: TextStyle(
                            color: accent,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          feature.subtitle,
                          style: TextStyle(
                            color: context.qtjp.heading,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          feature.description,
                          style: TextStyle(
                            color: context.qtjp.muted,
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (feature.supportsJlptLevel) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Cấp độ đang chọn: $selectedLevel',
                      key: const ValueKey('feature-selected-level'),
                      style: TextStyle(
                        color: context.qtjp.heading,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (onLevelChanged != null) ...[
                      const SizedBox(height: 12),
                      JlptLevelSelector(
                        selectedLevel: selectedLevel,
                        onSelected: onLevelChanged!,
                      ),
                    ],
                  ],
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.auto_stories_outlined,
                            color: context.qtjp.blue,
                            size: 36,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Nội dung đang được chuẩn bị',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.qtjp.heading,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Các bài học và hoạt động trong mục này sẽ sớm khả dụng. '
                            'Hãy tiếp tục khám phá các mục học tập của QTJP.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.qtjp.muted,
                              height: 1.6,
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
      ),
    );
  }
}
