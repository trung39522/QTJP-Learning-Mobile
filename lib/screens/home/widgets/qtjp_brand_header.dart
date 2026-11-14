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
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.asset(
            _assetPath,
            alignment: Alignment.centerLeft,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'QTJP Learning',
                  style: TextStyle(
                    color: context.qtjp.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
