import 'package:flutter/material.dart';

import '../../screens/assistant/kyuto_assistant_host.dart';

/// Reserves space in the body for Kyuto, above each page's bottom controls.
class KyutoScaffold extends StatelessWidget {
  const KyutoScaffold({
    this.scaffoldKey,
    this.appBar,
    this.body,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.endDrawer,
    this.showAssistant = true,
    super.key,
  });
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final PreferredSizeWidget? appBar;
  final Widget? body, bottomNavigationBar, endDrawer;
  final Color? backgroundColor;
  final bool showAssistant;

  @override
  Widget build(BuildContext context) {
    final controller = KyutoAssistantScope.maybeOf(context);
    final visible =
        showAssistant &&
        controller != null &&
        !controller.blocked &&
        MediaQuery.viewInsetsOf(context).bottom == 0;
    return Scaffold(
      key: scaffoldKey,
      appBar: appBar,
      backgroundColor: backgroundColor,
      body: visible
          ? Padding(padding: const EdgeInsets.only(bottom: 64), child: body)
          : body,
      bottomNavigationBar: bottomNavigationBar,
      endDrawer: endDrawer,
      floatingActionButton: visible ? const KyutoAvatarButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
