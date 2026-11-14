import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/navigation/app_routes.dart';

/// Native permission and local delivery; no push registration or API changes.
class DeviceNotifications {
  static const channel = MethodChannel('qtjp/device_notifications');
  static Future<String> status() async {
    try {
      return await channel.invokeMethod<String>('status') ?? 'unavailable';
    } on MissingPluginException {
      return 'unavailable';
    } on PlatformException {
      return 'unavailable';
    }
  }

  static Future<String> request() async =>
      await channel.invokeMethod<String>('request') ?? 'denied';
  static Future<void> settings() => channel.invokeMethod<void>('settings');
}

class NotificationPermissionCard extends StatefulWidget {
  const NotificationPermissionCard({super.key});
  @override
  State<NotificationPermissionCard> createState() =>
      _NotificationPermissionCardState();
}

class _NotificationPermissionCardState extends State<NotificationPermissionCard>
    with WidgetsBindingObserver {
  String _status = 'loading';
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final value = await DeviceNotifications.status();
    if (mounted) setState(() => _status = value);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _enable() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_status == 'denied' || _status == 'enabled') {
        await DeviceNotifications.settings();
      } else {
        final status = await DeviceNotifications.request();
        if (mounted) setState(() => _status = status);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Chưa mở được cài đặt thông báo. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _status == 'enabled'
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_rounded,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Thông báo trên điện thoại',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(switch (_status) {
            'enabled' => 'Đã cho phép thông báo.',
            'denied' => 'Thông báo đang tắt trong cài đặt điện thoại.',
            'unavailable' => 'Thiết bị này chưa hỗ trợ thông báo hệ thống.',
            'loading' => 'Đang kiểm tra quyền thông báo…',
            _ => 'Cho phép QTJP gửi thông báo đến điện thoại.',
          }, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          const Text(
            'Thông báo mới được cập nhật khi ứng dụng đang mở hoặc khi bạn quay lại ứng dụng.',
            style: TextStyle(fontSize: 11, height: 1.5),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          if (_status != 'unavailable' && _status != 'loading')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('notification-permission'),
                onPressed: _busy ? null : _enable,
                icon: Icon(
                  _status == 'enabled'
                      ? Icons.settings_outlined
                      : Icons.notifications_outlined,
                  size: 18,
                ),
                label: Text(
                  _status == 'enabled' || _status == 'denied'
                      ? 'Cài đặt thông báo'
                      : 'Cho phép thông báo',
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Polls the existing inbox only while foregrounded. Initial data is a baseline,
/// so enabling permission never replays the entire old inbox.
class DeviceNotificationsHost extends StatefulWidget {
  const DeviceNotificationsHost({
    required this.app,
    required this.navigatorKey,
    required this.child,
    super.key,
  });
  final AppController app;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  @override
  State<DeviceNotificationsHost> createState() =>
      _DeviceNotificationsHostState();
}

class _DeviceNotificationsHostState extends State<DeviceNotificationsHost>
    with WidgetsBindingObserver {
  Timer? _timer;
  int? _session, _loadingSession;
  bool _active = true, _baseline = false;
  final _seen = <int>{};
  Future<void> _nativeWork = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.app.addListener(_accountChanged);
    DeviceNotifications.channel.setMethodCallHandler((call) async {
      if (call.method == 'opened') _openInbox();
    });
    _timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(_poll()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _accountChanged();
      unawaited(_consumeTap());
    });
  }

  Future<void> _consumeTap() async {
    try {
      if (await DeviceNotifications.channel.invokeMethod<bool>('consumeTap') ==
              true &&
          mounted) {
        _openInbox();
      }
    } on MissingPluginException {
      /* Unsupported platforms have an in-app inbox. */
    } on PlatformException {
      /* Opening the application must remain available. */
    }
  }

  void _openInbox() {
    if (!mounted) return;
    widget.navigatorKey.currentState?.pushNamed(
      widget.app.isAuthenticated ? AppRoutes.notifications : AppRoutes.login,
    );
  }

  void _accountChanged() {
    if (!mounted || _session == widget.app.api.sessionVersion) return;
    _session = widget.app.api.sessionVersion;
    _seen.clear();
    _baseline = false;
    _loadingSession = null;
    _nativeWork = _nativeWork.then((_) async {
      try {
        await DeviceNotifications.channel.invokeMethod<void>('clear');
      } catch (_) {
        /* No native provider. */
      }
    });
    unawaited(_poll());
  }

  bool _current(int session) =>
      mounted &&
      widget.app.isAuthenticated &&
      widget.app.api.sessionVersion == session;
  Future<void> _poll() async {
    if (!mounted || !_active || !widget.app.isAuthenticated) return;
    final session = widget.app.api.sessionVersion;
    if (_loadingSession == session) return;
    _loadingSession = session;
    try {
      if (await DeviceNotifications.status() != 'enabled' ||
          !_current(session) ||
          !_active) {
        return;
      }
      final response = jsonObject(
        await widget.app.api.get('/api/notifications', authenticated: true),
      );
      if (!_current(session)) return;
      final items = jsonObjects(response['items']);
      final fresh = <Map<String, dynamic>>[];
      for (final item in items) {
        final id = item['id'];
        if (id is! int || id <= 0) continue;
        if (!_seen.contains(id) && _baseline && item['read'] != true) {
          fresh.add(item);
        }
        _seen.add(id);
      }
      _baseline = true;
      for (final item in fresh.reversed.take(3)) {
        _nativeWork = _nativeWork.then((_) async {
          if (!_current(session)) return;
          try {
            await DeviceNotifications.channel.invokeMethod<void>('show', {
              'id': item['id'],
              'title': jsonText(item, 'title'),
              'body': jsonText(item, 'content'),
            });
          } catch (_) {
            /* Inbox remains the source of truth. */
          }
        });
      }
      await _nativeWork;
    } catch (_) {
      /* The existing inbox owns its visible API errors. */
    } finally {
      if (_loadingSession == session) _loadingSession = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) unawaited(_poll());
  }

  @override
  void dispose() {
    widget.app.removeListener(_accountChanged);
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    DeviceNotifications.channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
