import 'package:flutter/material.dart';

import '../../../core/theme/qtjp_colors.dart';
import '../models/japan_inspiration_item.dart';

class JapanInspirationGallery extends StatefulWidget {
  const JapanInspirationGallery({required this.items, super.key});

  final List<JapanInspirationItem> items;

  @override
  State<JapanInspirationGallery> createState() =>
      _JapanInspirationGalleryState();
}

class _JapanInspirationGalleryState extends State<JapanInspirationGallery> {
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
            itemCount: widget.items.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 380,
              mainAxisExtent: 220,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (context, index) {
              return _InspirationPhoto(item: widget.items[index]);
            },
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 220,
              child: PageView.builder(
                key: const ValueKey('japan-inspiration-carousel'),
                controller: _pageController,
                itemCount: widget.items.length,
                onPageChanged: (index) => setState(() => _activePage = index),
                padEnds: false,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == widget.items.length - 1 ? 0 : 12,
                    ),
                    child: _InspirationPhoto(item: widget.items[index]),
                  );
                },
              ),
            ),
            const SizedBox(height: 13),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.items.length, (index) {
                final active = index == _activePage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: active ? 22 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? QTJPColors.red : QTJPColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _InspirationPhoto extends StatelessWidget {
  const _InspirationPhoto({required this.item});

  final JapanInspirationItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: item.alt,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              item.assetPath,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(
                  color: QTJPColors.softBlue,
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: QTJPColors.muted,
                    ),
                  ),
                );
              },
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xC0031A40)],
                  stops: [0.42, 1],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFDCEAF6),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
