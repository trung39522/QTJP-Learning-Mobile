import 'dart:math' as math;

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
  int _activePage = 0;
  double _dragDistance = 0;
  bool _dragging = false;

  void _select(int index) => setState(() {
    _activePage = index % widget.features.length;
    _dragDistance = 0;
    _dragging = false;
  });

  int _distance(int index) {
    final count = widget.features.length;
    final distance = (index - _activePage + count) % count;
    return distance > count / 2 ? distance - count : distance;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.features.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = math.min(constraints.maxWidth * 0.8, 360.0);
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final cardHeight = cardWidth + math.max(0.0, textScale - 1) * 240;
        final order = List.generate(widget.features.length, (index) => index)
          ..sort((a, b) => _distance(b).abs().compareTo(_distance(a).abs()));

        return Column(
          children: [
            ClipRect(
              child: GestureDetector(
                key: const ValueKey('home-feature-carousel'),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => setState(() {
                  _dragDistance = 0;
                  _dragging = true;
                }),
                onHorizontalDragUpdate: (details) => setState(() {
                  _dragDistance += details.delta.dx;
                }),
                onHorizontalDragCancel: () => _select(_activePage),
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() > 250 || _dragDistance.abs() > 40) {
                    final direction = velocity.abs() > 250
                        ? velocity
                        : _dragDistance;
                    _select(_activePage + (direction < 0 ? 1 : -1));
                  } else {
                    _select(_activePage);
                  }
                },
                child: SizedBox(
                  height: cardHeight + 62,
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Positioned.fill(
                        child: CustomPaint(painter: _ArcGuidePainter()),
                      ),
                      for (final index in order)
                        Positioned(
                          key: ValueKey(widget.features[index].id),
                          left: (constraints.maxWidth - cardWidth) / 2,
                          top: 12,
                          width: cardWidth,
                          height: cardHeight,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(
                              end:
                                  _distance(index) +
                                  (_dragDistance / (cardWidth * 0.94)).clamp(
                                    -1.0,
                                    1.0,
                                  ),
                            ),
                            duration: _dragging
                                ? Duration.zero
                                : const Duration(milliseconds: 360),
                            curve: Curves.easeOutCubic,
                            child: ExcludeSemantics(
                              excluding: _distance(index).abs() > 1,
                              child: IgnorePointer(
                                ignoring: _distance(index).abs() > 1,
                                child: HomeFeatureCard(
                                  feature: widget.features[index],
                                  selectedLevel: widget.selectedLevel,
                                  isActive: index == _activePage,
                                  onTap: () {
                                    if (index == _activePage) {
                                      widget.onFeatureTap(
                                        widget.features[index],
                                      );
                                    } else {
                                      _select(index);
                                    }
                                  },
                                ),
                              ),
                            ),
                            builder: (context, distance, child) {
                              final depth = distance.abs();
                              return Transform.translate(
                                offset: Offset(
                                  distance * cardWidth * 0.94,
                                  depth * depth * 34,
                                ),
                                child: Transform.rotate(
                                  angle: distance * 11 * math.pi / 180,
                                  child: Transform.scale(
                                    scale: math.max(0.62, 1 - depth * 0.14),
                                    child: Opacity(
                                      opacity: depth > 2.5
                                          ? 0
                                          : (1 - depth * 0.16).clamp(0, 1),
                                      child: child,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _arrow('Chức năng trước', Icons.arrow_back_rounded, -1),
                const SizedBox(width: 4),
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: List.generate(widget.features.length, (index) {
                      final active = index == _activePage;
                      return Semantics(
                        selected: active,
                        child: InkWell(
                          onTap: () => _select(index),
                          borderRadius: BorderRadius.circular(24),
                          child: Tooltip(
                            message: widget.features[index].title,
                            child: SizedBox(
                              width: active ? 30 : 20,
                              height: 44,
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: active ? 26 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? QTJPColors.red
                                        : const Color(0xFFCBD7E5),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 4),
                _arrow('Chức năng tiếp theo', Icons.arrow_forward_rounded, 1),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Vuốt sang hai bên · Chạm thẻ ở giữa để mở chức năng',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.qtjp.muted,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _arrow(String label, IconData icon, int direction) {
    return IconButton.outlined(
      tooltip: label,
      onPressed: () => _select(_activePage + direction),
      style: IconButton.styleFrom(
        foregroundColor: context.qtjp.heading,
        side: BorderSide(color: context.qtjp.border),
        minimumSize: const Size(44, 44),
      ),
      icon: Icon(icon, size: 18),
    );
  }
}

class _ArcGuidePainter extends CustomPainter {
  const _ArcGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawArc(
      Rect.fromLTWH(
        -size.width * 0.15,
        65,
        size.width * 1.3,
        size.height * 1.5,
      ),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFFDCE8F3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_ArcGuidePainter oldDelegate) => false;
}
