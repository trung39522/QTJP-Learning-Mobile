import 'package:flutter/material.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/theme/qtjp_colors.dart';
import '../../core/theme/qtjp_spacing.dart';
import 'models/home_feature_item.dart';
import 'models/japan_inspiration_item.dart';
import 'models/learning_journey_item.dart';
import 'widgets/home_feature_carousel.dart';
import 'widgets/home_section_header.dart';
import 'widgets/japan_inspiration_gallery.dart';
import 'widgets/jlpt_level_selector.dart';
import 'widgets/kyuto_entry_button.dart';
import 'widgets/learning_journey.dart';
import 'widgets/qtjp_brand_header.dart';
import 'widgets/qtjp_home_hero.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.selectedLevel,
    required this.onLevelChanged,
    required this.onStartLearning,
    super.key,
  });

  final String selectedLevel;
  final ValueChanged<String> onLevelChanged;
  final VoidCallback onStartLearning;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color navy = QTJPColors.navy;
  static const Color muted = QTJPColors.muted;

  String get selectedLevel => widget.selectedLevel;

  void _openFeature(String id) {
    Navigator.of(context).pushNamed(
      id == 'video'
          ? '/learn/video'
          : AppRoutes.feature(id, level: selectedLevel),
    );
  }

  void _openKyuto() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return KyutoPreviewSheet(
          onActionSelected: (action) {
            Navigator.of(sheetContext).pop();
            switch (action) {
              case 'Tra từ vựng':
                _openFeature('dictionary');
              case 'Giải thích ngữ pháp':
                _openFeature('grammar');
              case 'Luyện đề JLPT':
                _openFeature('exam');
              default:
                Navigator.of(context).pushNamed(AppRoutes.assistant);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const QTJPBrandHeader(),
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.notifications),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const PageStorageKey('home-scroll'),
          padding: const EdgeInsets.fromLTRB(
            QTJPSpacing.screenHorizontal,
            20,
            QTJPSpacing.screenHorizontal,
            28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: QTJPSpacing.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QTJPHomeHero(
                    onPrimaryPressed: widget.onStartLearning,
                    onAlphabetPressed: () => _openFeature('alphabet'),
                  ),
                  const SizedBox(height: 27),
                  _buildSectionHeading('Chọn cấp độ JLPT', 'N5 đến N1'),
                  const SizedBox(height: 13),
                  JlptLevelSelector(
                    selectedLevel: selectedLevel,
                    onSelected: widget.onLevelChanged,
                  ),
                  const SizedBox(height: 25),
                  _buildSectionHeading(
                    'Khám phá QTJP',
                    'Lộ trình $selectedLevel',
                  ),
                  const SizedBox(height: 14),
                  HomeFeatureCarousel(
                    features: homeFeatureItems,
                    selectedLevel: selectedLevel,
                    onFeatureTap: (feature) => _openFeature(feature.id),
                  ),
                  const SizedBox(height: 40),
                  const HomeSectionHeader(
                    kicker: 'CẢM HỨNG TỪ NHẬT BẢN',
                    title: 'Học ngôn ngữ, khám phá cả một nền văn hóa',
                    description: 'Từ sắc hoa anh đào đến núi Phú Sĩ và những con phố nhộn nhịp — thêm cảm hứng cho mỗi ngày học.',
                  ),
                  const SizedBox(height: 16),
                  const JapanInspirationGallery(items: japanInspirationItems),
                  const SizedBox(height: 40),
                  const HomeSectionHeader(
                    kicker: 'LỘ TRÌNH HỌC CÙNG QTJP',
                    title: 'Chinh phục tiếng Nhật như chinh phục núi Phú Sĩ',
                    description: 'Đi qua bốn chặng từ làm quen bảng chữ cái đến kiểm tra trình độ JLPT.',
                  ),
                  const SizedBox(height: 16),
                  LearningJourney(
                    items: learningJourneyItems,
                    onItemTap: (item) => _openFeature(switch (item.number) {
                      '01' => 'alphabet',
                      '02' => 'flashcard',
                      '03' => 'writing',
                      _ => 'exam',
                    }),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Nội dung học tập sẽ sớm khả dụng trên QTJP Mobile.',
                    style: TextStyle(
                      fontSize: 12,
                      color: muted.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: KyutoEntryButton(onPressed: _openKyuto),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSectionHeading(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              color: navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
      ],
    );
  }
}
