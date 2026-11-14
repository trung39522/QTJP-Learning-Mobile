import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_controller.dart';
import '../../../core/theme/qtjp_colors.dart';
import '../../home/widgets/home_account_avatar.dart';
import '../models/account_presentation.dart';
import 'account_menu_content.dart';

class AccountMenuPopover extends StatefulWidget {
  const AccountMenuPopover({
    this.enabled = true,
    this.nameWidth = 0,
    this.onVisibilityChanged,
    super.key,
  });
  final bool enabled;
  final double nameWidth;
  final ValueChanged<bool>? onVisibilityChanged;
  @override
  State<AccountMenuPopover> createState() => _AccountMenuPopoverState();
}

class _AccountMenuPopoverState extends State<AccountMenuPopover>
    with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final _curve = CurvedAnimation(
    parent: _animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  bool _open = false;

  Future<void> _close() async {
    if (!_open) return;
    await _animation.reverse();
    if (!mounted) return;
    _portal.hide();
    setState(() => _open = false);
    widget.onVisibilityChanged?.call(false);
  }

  void _toggle() {
    if (_open) {
      unawaited(_close());
      return;
    }
    setState(() => _open = true);
    _portal.show();
    _animation.forward(from: 0);
    widget.onVisibilityChanged?.call(true);
  }

  @override
  void didUpdateWidget(covariant AccountMenuPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _open) unawaited(_close());
  }

  @override
  void dispose() {
    _curve.dispose();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final account = AccountPresentation(app.user);
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _open) unawaited(_close());
      },
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _portal,
        overlayLocation: OverlayChildLocation.rootOverlay,
        overlayChildBuilder: (context, info) {
          final rect = MatrixUtils.transformRect(
            info.childPaintTransform,
            Offset.zero & info.childSize,
          );
          final media = MediaQuery.of(context);
          final width = math.min(
            220.0,
            info.overlaySize.width - media.padding.horizontal - 24,
          );
          final left = (rect.right - width)
              .clamp(
                media.padding.left + 12,
                math.max(
                  media.padding.left + 12,
                  info.overlaySize.width - media.padding.right - width - 12,
                ),
              )
              .toDouble();
          final top = rect.bottom + 8;
          final height = math.max(
            0.0,
            info.overlaySize.height -
                top -
                math.max(media.padding.bottom, media.viewInsets.bottom) -
                12,
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Semantics(
                  label: 'Đóng menu tài khoản',
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: const ColoredBox(color: Colors.transparent),
                  ),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                width: width,
                child: FadeTransition(
                  opacity: _curve,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, -0.025),
                      end: Offset.zero,
                    ).animate(_curve),
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.escape): () =>
                            unawaited(_close()),
                      },
                      child: FocusScope(
                        autofocus: true,
                        child: Material(
                          key: const ValueKey('account-popover'),
                          color: context.qtjp.surface,
                          elevation: 6,
                          shadowColor: const Color(0x2606275B),
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.antiAlias,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: height),
                            child: AccountMenuContent(onClose: _close),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: Tooltip(
          message: app.isAuthenticated
              ? 'Tài khoản: ${account.name}'
              : 'Tài khoản',
          child: Semantics(
            expanded: _open,
            button: true,
            child: Material(
              color: _open ? context.qtjp.soft : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                key: const ValueKey('home-account-avatar'),
                onTap: widget.enabled ? _toggle : null,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const HomeAccountAvatar(plain: true),
                      if (app.isAuthenticated && widget.nameWidth > 0) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: widget.nameWidth,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.name,
                                key: const ValueKey('header-account-name'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.qtjp.heading,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (account.vipAt(DateTime.now()) &&
                                  MediaQuery.textScalerOf(context).scale(12) <=
                                      15)
                                const Text(
                                  'VIP',
                                  style: TextStyle(
                                    color: Color(0xFFAD8100),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
