import 'package:flutter/material.dart';

import '../../../core/theme/qtjp_colors.dart';

class QTJPBrandHeader extends StatelessWidget {
  const QTJPBrandHeader({super.key});

  static const _assetPath = 'assets/branding/qtjp_logo.png';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'QTJP Japanese Learning',
      child: SizedBox(
        width: 146,
        height: 44,
        child: Image.asset(
          _assetPath,
          alignment: Alignment.centerLeft,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stackTrace) {
            return const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'QTJP Learning',
                style: TextStyle(
                  color: QTJPColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
