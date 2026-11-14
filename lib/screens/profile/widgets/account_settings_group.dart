import 'package:flutter/material.dart';

import '../../../core/theme/qtjp_colors.dart';

class AccountSettingsGroup extends StatelessWidget {
  const AccountSettingsGroup({
    required this.title,
    required this.children,
    super.key,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 9),
          child: Text(
            title,
            style: TextStyle(
              color: context.qtjp.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Material(
          color: context.qtjp.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: context.qtjp.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 58, endIndent: 16),
                children[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class AccountSettingTile extends StatelessWidget {
  const AccountSettingTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    super.key,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 64,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: Icon(icon, color: context.qtjp.heading, size: 22),
    title: Text(
      title,
      style: TextStyle(
        color: context.qtjp.heading,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    ),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: TextStyle(
              color: context.qtjp.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
    trailing: Icon(
      Icons.chevron_right_rounded,
      color: context.qtjp.muted,
      size: 20,
    ),
    onTap: onTap,
  );
}
