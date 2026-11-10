import 'package:flutter/material.dart';

import '../../../core/theme/qtjp_colors.dart';
import '../models/home_feature_item.dart';
import 'home_feature_card.dart';

class HomeFeatureCarousel extends StatefulWidget {
  const HomeFeatureCarousel({
    required this.features,
    required this.selectedLevel,
    required this.onFeatureTap,
    super.key,
  });

  final List<HomeFeatureItem> features;
  final String selectedLevel;
  final ValueChanged<HomeFeatureItem> onFeatureTap;

  @override
  State<HomeFeatureCarousel> createState() => _HomeFeatureCarouselState();
}

class _HomeFeatureCarouselState extends State<HomeFeatureCarousel> {
  late final PageController _pageController;
  int _activePage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.features.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 310,
              mainAxisExtent: 300,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (context, index) {
              final feature = widget.features[index];
              return HomeFeatureCard(
                feature: feature,
                selectedLevel: widget.selectedLevel,
                onTap: () => widget.onFeatureTap(feature),
              );
            },
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 310,
              child: PageView.builder(
                key: const ValueKey('home-feature-carousel'),
                controller: _pageController,
                itemCount: widget.features.length,
                onPageChanged: (index) => setState(() => _activePage = index),
                padEnds: false,
                itemBuilder: (context, index) {
                  final feature = widget.features[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == widget.features.length - 1 ? 0 : 12,
                    ),
                    child: HomeFeatureCard(
                      feature: feature,
                      selectedLevel: widget.selectedLevel,
                      onTap: () => widget.onFeatureTap(feature),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.features.length, (index) {
                final active = index == _activePage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: active ? 22 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? QTJPColors.navy : QTJPColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
            const SizedBox(height: 9),
            const Text(
              'Vuốt sang hai bên để khám phá đầy đủ chức năng',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: QTJPColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}
