import 'package:flutter/material.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/theme/qtjp_colors.dart';
import '../home/models/home_feature_item.dart';
import '../home/widgets/jlpt_level_selector.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({
    required this.selectedLevel,
    required this.onLevelChanged,
    super.key,
  });

  final String selectedLevel;
  final ValueChanged<String> onLevelChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Học tập cùng QTJP')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const PageStorageKey('learning-scroll'),
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mỗi ngày một bước tiến',
                    style: TextStyle(
                      color: QTJPColors.navyDark,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chọn cấp độ và khám phá cách học phù hợp với bạn.',
                    style: TextStyle(color: QTJPColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  JlptLevelSelector(
                    selectedLevel: selectedLevel,
                    onSelected: onLevelChanged,
                  ),
                  const SizedBox(height: 24),
                  for (final feature in homeFeatureItems) ...[
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        key: ValueKey('learning-${feature.id}'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: QTJPColors.softBlue,
                          child: Text(
                            feature.symbol,
                            style: const TextStyle(color: QTJPColors.navy),
                          ),
                        ),
                        title: Text(
                          feature.title,
                          style: const TextStyle(
                            color: QTJPColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(feature.subtitle),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: QTJPColors.blue,
                        ),
                        onTap: () => Navigator.of(context).pushNamed(
                          feature.id == 'video'
                              ? '/learn/video'
                              : AppRoutes.feature(
                                  feature.id,
                                  level: selectedLevel,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
