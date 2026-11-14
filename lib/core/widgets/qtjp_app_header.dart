import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../screens/home/widgets/qtjp_brand_header.dart';
import '../../screens/profile/widgets/account_menu_popover.dart';
import 'notification_badge_button.dart';

class QTJPAppHeader extends StatelessWidget implements PreferredSizeWidget {
  const QTJPAppHeader({
    this.accountActionsEnabled = true,
    this.onMenuVisibilityChanged,
    super.key,
  });
  final bool accountActionsEnabled;
  final ValueChanged<bool>? onMenuVisibilityChanged;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    centerTitle: false,
    toolbarHeight: 64,
    titleSpacing: 16,
    title: LayoutBuilder(
      builder: (context, constraints) {
        final availableName = math.min(112.0, constraints.maxWidth - 272);
        final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
        final showName =
            AppScope.of(context).isAuthenticated && availableName >= 64 * scale;
        return Row(
          children: [
            const QTJPBrandHeader(),
            const Spacer(),
            NotificationBadgeButton(enabled: accountActionsEnabled),
            const SizedBox(width: 8),
            AccountMenuPopover(
              enabled: accountActionsEnabled,
              nameWidth: showName ? availableName : 0,
              onVisibilityChanged: onMenuVisibilityChanged,
            ),
          ],
        );
      },
    ),
  );
}
