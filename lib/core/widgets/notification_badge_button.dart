import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../navigation/app_routes.dart';
import '../network/api_client.dart';
import '../theme/qtjp_colors.dart';

class NotificationBadgeButton extends StatefulWidget {
  const NotificationBadgeButton({this.enabled = true, super.key});
  final bool enabled;
  @override
  State<NotificationBadgeButton> createState() =>
      _NotificationBadgeButtonState();
}

class _NotificationBadgeButtonState extends State<NotificationBadgeButton>
    with WidgetsBindingObserver {
  AppController? _app;
  Timer? _timer;
  int? _session, _loadingSession, _unread;
  bool _failed = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_foreground && widget.enabled) unawaited(_load());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (!identical(app, _app) || _session != app.api.sessionVersion) {
      _app = app;
      _session = app.api.sessionVersion;
      _loadingSession = null;
      _unread = null;
      _failed = false;
      // Start after build: a synchronous 401 must not rebuild AppScope here.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
  }

  Future<void> _load() async {
    final app = _app;
    if (!mounted || app == null || !app.isAuthenticated) return;
    final session = app.api.sessionVersion;
    if (_loadingSession == session) return;
    _loadingSession = session;
    try {
      final data = jsonObject(
        await app.api.get(
          '/api/notifications/unread-count',
          authenticated: true,
        ),
      );
      final count = data['unreadCount'];
      if (count is! num || !count.isFinite || count < 0) {
        throw const ApiException('Số thông báo chưa đọc không hợp lệ.');
      }
      if (mounted &&
          identical(app, _app) &&
          session == app.api.sessionVersion) {
        setState(() {
          _unread = count.toInt();
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted &&
          identical(app, _app) &&
          session == app.api.sessionVersion) {
        setState(() {
          _unread = null;
          _failed = true;
        });
      }
    } finally {
      if (identical(app, _app) && _loadingSession == session) {
        _loadingSession = null;
      }
    }
  }

  Future<void> _open() async {
    final app = _app!;
    final session = app.api.sessionVersion;
    await Navigator.of(context).pushNamed(
      app.isAuthenticated ? AppRoutes.notifications : AppRoutes.login,
    );
    if (mounted && session == app.api.sessionVersion) await _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && widget.enabled) unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: _failed
        ? 'Chưa tải được số thông báo chưa đọc'
        : _unread == null
        ? 'Thông báo'
        : 'Thông báo, $_unread chưa đọc',
    child: IconButton(
      key: const ValueKey('header-notifications'),
      tooltip: 'Thông báo',
      onPressed: widget.enabled ? _open : null,
      icon: Badge(
        key: const ValueKey('notification-badge'),
        isLabelVisible: (_unread ?? 0) > 0,
        backgroundColor: QTJPColors.red,
        label: Text((_unread ?? 0) > 99 ? '99+' : '${_unread ?? 0}'),
        child: const Icon(Icons.notifications_none_rounded),
      ),
    ),
  );
}
