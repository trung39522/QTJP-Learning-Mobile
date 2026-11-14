import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/navigation/app_routes.dart';
import '../../core/theme/qtjp_colors.dart';
import 'assistant_screen.dart';

class KyutoAssistantController extends ChangeNotifier {
  final _exams = <Object>{};
  bool _open = false;
  bool _scheduled = false;
  bool _disposed = false;
  LocalHistoryEntry? _history;
  String? initialMessage;

  bool get blocked => _exams.isNotEmpty;
  bool get isOpen => _open && !blocked;

  void show(BuildContext context, {String? message}) {
    if (blocked) return;
    initialMessage = message;
    if (!_open) {
      _open = true;
      _history = LocalHistoryEntry(
        onRemove: () {
          _history = null;
          if (_open) {
            _open = false;
            FocusManager.instance.primaryFocus?.unfocus();
            notifyListeners();
          }
        },
      );
      ModalRoute.of(context)?.addLocalHistoryEntry(_history!);
    }
    notifyListeners();
  }

  void close() {
    _open = false;
    FocusManager.instance.primaryFocus?.unfocus();
    final history = _history;
    _history = null;
    history?.remove();
    notifyListeners();
  }

  void setExamActive(Object owner, bool active) {
    if (_disposed) return;
    final changed = active ? _exams.add(owner) : _exams.remove(owner);
    if (!changed || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed) return;
      if (blocked && _open) {
        close();
      } else {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _open = false;
    _history?.remove();
    super.dispose();
  }
}

class KyutoAssistantScope extends InheritedNotifier<KyutoAssistantController> {
  const KyutoAssistantScope({
    required KyutoAssistantController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static KyutoAssistantController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<KyutoAssistantScope>()
      ?.notifier;

  static void show(BuildContext context, {String? message}) {
    final controller = maybeOf(context);
    if (controller == null) {
      Navigator.pushNamed(context, AppRoutes.assistant);
    } else {
      controller.show(context, message: message);
    }
  }
}

class KyutoRouteObserver extends NavigatorObserver {
  KyutoRouteObserver(this.controller);
  final KyutoAssistantController controller;
  final _routes = <Route<dynamic>>[];
  void _sync() => controller.setExamActive(
    this,
    _routes.any(
      (r) =>
          r.settings.name == AppRoutes.login ||
          r.settings.name == AppRoutes.register,
    ),
  );
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _sync();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _sync();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _sync();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    _sync();
  }
}

class KyutoAvatarButton extends StatelessWidget {
  const KyutoAvatarButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = KyutoAssistantScope.maybeOf(context)!;
    return Tooltip(
      message: 'Kyuto AI',
      child: Semantics(
        label: 'Kyuto AI',
        button: true,
        child: Material(
          elevation: 4,
          shadowColor: QTJPColors.navy.withValues(alpha: .15),
          color: context.qtjp.surface,
          shape: CircleBorder(side: BorderSide(color: context.qtjp.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('kyuto-avatar'),
            onTap: () => controller.isOpen
                ? controller.close()
                : controller.show(context),
            child: SizedBox.square(
              dimension: 48,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/mascot/kyuto_avatar.webp',
                  fit: BoxFit.contain,
                  cacheWidth: 144,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.auto_awesome, color: context.qtjp.heading),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sits above the root Navigator, so one conversation survives page changes.
class KyutoAssistantHost extends StatefulWidget {
  const KyutoAssistantHost({
    required this.controller,
    required this.navigatorKey,
    required this.child,
    super.key,
  });
  final KyutoAssistantController controller;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<KyutoAssistantHost> createState() => _KyutoAssistantHostState();
}

class _KyutoAssistantHostState extends State<KyutoAssistantHost> {
  late final _entry = OverlayEntry(
    builder: (_) => _KyutoAssistantContent(
      controller: widget.controller,
      navigatorKey: widget.navigatorKey,
      child: widget.child,
    ),
  );

  @override
  void didUpdateWidget(covariant KyutoAssistantHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}

class _KyutoAssistantContent extends StatelessWidget {
  const _KyutoAssistantContent({
    required this.controller,
    required this.navigatorKey,
    required this.child,
  });
  final KyutoAssistantController controller;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final bottom =
            math.max(media.viewInsets.bottom, media.viewPadding.bottom) + 12;
        final available = math.max(
          0.0,
          constraints.maxHeight - bottom - media.viewPadding.top - 12,
        );
        final height = math.min(400.0, available * .8);
        final width = math.max(0.0, math.min(320.0, constraints.maxWidth - 32));
        return Stack(
          children: [
            child,
            if (controller.isOpen)
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('kyuto-chat-dismiss'),
                  behavior: HitTestBehavior.opaque,
                  onTap: controller.close,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            Positioned(
              key: const ValueKey('kyuto-panel-position'),
              left: (constraints.maxWidth - width) / 2,
              top: media.viewPadding.top + 12 + (available - height) / 2,
              width: width,
              height: height,
              child: Offstage(
                offstage: !controller.isOpen,
                child: TickerMode(
                  enabled: controller.isOpen,
                  child: Material(
                    key: const ValueKey('kyuto-chatbox'),
                    color: context.qtjp.surface,
                    elevation: 12,
                    shadowColor: const Color(0xFFB5356B).withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: AssistantScreen(
                      compact: true,
                      initialMessage: controller.initialMessage,
                      onClose: controller.close,
                      onNavigate: (route) {
                        controller.close();
                        if (route == '/') {
                          navigatorKey.currentState?.popUntil(
                            (route) => route.isFirst,
                          );
                        } else {
                          navigatorKey.currentState?.pushNamed(route);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
