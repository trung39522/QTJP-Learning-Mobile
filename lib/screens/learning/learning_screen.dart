import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/theme/qtjp_colors.dart';
import '../home/models/home_feature_item.dart';
import '../home/widgets/jlpt_level_selector.dart';
import '../grammar/conjugation_screen.dart';

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
    final features = [
      'flashcard',
      'grammar',
      'alphabet',
      'writing',
      'video',
    ].map((id) => homeFeatureItems.firstWhere((f) => f.id == id));
    return KyutoScaffold(
      showAssistant: false,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const PageStorageKey('learning-scroll'),
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Học tập',
                    key: const ValueKey('learning-heading'),
                    style: TextStyle(
                      color: context.qtjp.heading,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Trình độ của bạn',
                          style: TextStyle(
                            color: context.qtjp.heading,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        'JLPT $selectedLevel',
                        style: TextStyle(
                          color: context.qtjp.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  JlptLevelSelector(
                    selectedLevel: selectedLevel,
                    onSelected: onLevelChanged,
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Khám phá bài học',
                    style: TextStyle(
                      color: context.qtjp.heading,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kiến thức, thực hành và công cụ hỗ trợ học tiếng Nhật.',
                    style: TextStyle(
                      color: context.qtjp.muted,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final feature in features) ...[
                    if (feature.id == 'flashcard') ...[
                      _LearningFeatureTile(
                        key: const ValueKey('learning-vocabulary'),
                        icon: Icons.translate_rounded,
                        title: 'Từ vựng',
                        subtitle: 'Kanji, cách đọc, nghĩa và ví dụ theo bài',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.feature('vocabulary', level: selectedLevel),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _LearningFeatureTile(
                      key: ValueKey('learning-${feature.id}'),
                      icon: switch (feature.id) {
                        'dictionary' => Icons.search_rounded,
                        'flashcard' => Icons.style_outlined,
                        'grammar' => Icons.menu_book_rounded,
                        'alphabet' => Icons.grid_view_rounded,
                        'writing' => Icons.edit_note_rounded,
                        _ => Icons.play_circle_outline_rounded,
                      },
                      title: feature.id == 'flashcard'
                          ? 'Flashcard'
                          : feature.title,
                      subtitle: feature.subtitle,
                      onTap: () => Navigator.pushNamed(
                        context,
                        feature.id == 'video'
                            ? '/learn/video'
                            : AppRoutes.feature(
                                feature.id,
                                level: selectedLevel,
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (feature.id == 'grammar') ...[
                      _LearningFeatureTile(
                        key: const ValueKey('learning-conjugation'),
                        icon: Icons.table_chart_outlined,
                        title: 'Bảng chia thể',
                        subtitle: '12 thể động từ và bảng quy tắc theo nhóm',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const ConjugationScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LearningFeatureTile extends StatelessWidget {
  const _LearningFeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: context.qtjp.soft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: context.qtjp.blue, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: context.qtjp.heading,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.qtjp.muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.qtjp.blue,
        size: 22,
      ),
      onTap: onTap,
    ),
  );
}
