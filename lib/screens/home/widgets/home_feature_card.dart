import 'package:flutter/material.dart';

import '../../../core/theme/qtjp_colors.dart';
import '../models/home_feature_item.dart';

class HomeFeatureCard extends StatelessWidget {
  const HomeFeatureCard({
    required this.feature,
    required this.selectedLevel,
    required this.onTap,
    this.isActive = false,
    super.key,
  });

  final HomeFeatureItem feature;
  final String selectedLevel;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final accent = feature.accent == HomeFeatureAccent.red
        ? QTJPColors.red
        : QTJPColors.navy;
    final foreground = isActive ? Colors.white : context.qtjp.heading;
    final secondary = isActive ? const Color(0xFFA9CBEA) : context.qtjp.blue;

    return Semantics(
      button: true,
      label:
          '${feature.title}${feature.supportsJlptLevel ? ' · $selectedLevel' : ''}. ${isActive ? 'Mở chức năng' : 'Chọn để xem chi tiết'}',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: QTJPColors.navy.withValues(alpha: isActive ? 0.2 : 0.06),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Material(
          color: isActive ? QTJPColors.navy : context.qtjp.surface,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0C3269), QTJPColors.navy],
                      )
                    : null,
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF315489)
                      : context.qtjp.border,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 20,
                    top: 12,
                    child: ExcludeSemantics(
                      child: Text(
                        feature.symbol,
                        style: TextStyle(
                          color: foreground.withValues(alpha: 0.09),
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isActive ? Colors.white : accent,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Text(
                                feature.symbol,
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: isActive
                                      ? QTJPColors.navy
                                      : Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                '${feature.number} / 07',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isActive
                                      ? const Color(0xFF94B1D5)
                                      : const Color(0xFF9DAFC7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          feature.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 17,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          feature.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: secondary,
                            fontSize: 11,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final lineHeight =
                                  MediaQuery.textScalerOf(context).scale(11) *
                                  1.5;
                              if (constraints.maxHeight < lineHeight * 2) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                feature.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isActive
                                      ? const Color(0xFFCADAF0)
                                      : context.qtjp.muted,
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isActive
                                    ? feature.actionLabel
                                    : 'Xem tính năng',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : QTJPColors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: isActive ? Colors.white : QTJPColors.red,
                              size: 17,
                            ),
                          ],
                        ),
                      ],
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
