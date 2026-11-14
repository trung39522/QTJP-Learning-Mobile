import 'package:flutter/material.dart';

import '../theme/app_theme_controller.dart';
import '../theme/qtjp_colors.dart';

class AppearanceTile extends StatelessWidget {
  const AppearanceTile({this.compact = false, super.key});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final controller = AppThemeScope.maybeOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      key: const ValueKey('appearance-toggle'),
      dense: compact,
      minTileHeight: compact ? 48 : 64,
      horizontalTitleGap: compact ? 12 : 16,
      contentPadding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16),
      leading: Icon(
        dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
        color: context.qtjp.heading,
        size: compact ? 20 : 23,
      ),
      title: Text(
        'Giao diện',
        style: TextStyle(
          fontSize: compact ? 13 : 15,
          fontWeight: FontWeight.w700,
          color: context.qtjp.heading,
        ),
      ),
      subtitle: Text(
        dark ? 'Chế độ tối' : 'Chế độ sáng',
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          color: context.qtjp.muted,
        ),
      ),
      trailing: compact
          ? Icon(
              dark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              size: 21,
              color: dark ? context.qtjp.blue : const Color(0xFFF4B000),
            )
          : Switch(
              value: dark,
              onChanged: controller == null ? null : (_) => controller.toggle(),
            ),
      onTap: controller?.toggle,
    );
  }
}
