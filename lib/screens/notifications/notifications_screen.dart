import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/api_error_view.dart';
import '../assistant/assistant_repository.dart';
import '../profile/security_screen.dart';
import 'device_notifications.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late AppController _app;
  int? _session;
  List<Map<String, dynamic>> _items = [];
  int _unread = 0;
  bool _busy = false, _loaded = false;
  Object? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    if (_session != _app.api.sessionVersion) {
      _session = _app.api.sessionVersion;
      _items = [];
      _unread = 0;
      _loaded = false;
      _error = null;
      _busy = false;
      if (_app.isAuthenticated) unawaited(_load());
    }
  }

  Future<void> _run(Future<void> Function(int session) action) async {
    if (_busy || !_app.isAuthenticated) return;
    final session = _app.api.sessionVersion;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(session);
    } catch (error) {
      if (mounted && session == _app.api.sessionVersion) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && session == _app.api.sessionVersion) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _fetch(int session) async {
    final response = jsonObject(
      await _app.api.get('/api/notifications', authenticated: true),
    );
    final items = jsonObjects(response['items']);
    if (mounted && session == _app.api.sessionVersion) {
      _items = items;
      _unread = (response['unreadCount'] as num?)?.toInt() ?? 0;
      _loaded = true;
    }
  }

  Future<void> _load() => _run(_fetch);
  Future<void> _read(Map<String, dynamic> item) => _run((session) async {
    final id = item['id'];
    if (id is! int || id <= 0) {
      throw const ApiException('Thông báo thiếu mã định danh.');
    }
    if (item['read'] != true) {
      await _app.api.request(
        'PATCH',
        '/api/notifications/$id/read',
        authenticated: true,
      );
    }
    await _fetch(session);
    if (!mounted || session != _app.api.sessionVersion) return;
    final path = jsonText(item, 'targetUrl');
    if (path == '/security') {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const SecurityScreen()),
      );
    } else {
      final route = assistantMobileRoute(path);
      if (route != null) await Navigator.pushNamed(context, route);
    }
  });
  Future<void> _readAll() => _run((session) async {
    await _app.api.request(
      'PATCH',
      '/api/notifications/read-all',
      authenticated: true,
    );
    await _fetch(session);
  });
  @override
  Widget build(BuildContext context) => KyutoScaffold(
    appBar: AppBar(
      title: const Text('Thông báo'),
      actions: [
        IconButton(
          tooltip: 'Tải lại thông báo',
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: !_app.isAuthenticated
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ApiErrorView(
                error: const ApiException(
                  'Đăng nhập để xem thông báo của tài khoản.',
                  status: 401,
                ),
                onRetry: _load,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const NotificationPermissionCard(),
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  ApiErrorView(error: _error!, onRetry: _load),
                Text('$_unread thông báo chưa đọc'),
                if (_unread > 0)
                  TextButton(
                    onPressed: _busy ? null : _readAll,
                    child: const Text('Đánh dấu tất cả đã đọc'),
                  ),
                if (_loaded && _items.isEmpty)
                  const Text('Bạn chưa có thông báo.'),
                for (final item in _items)
                  Card(
                    child: ListTile(
                      key: ValueKey('notification-${item['id']}'),
                      leading: Icon(
                        item['read'] == true
                            ? Icons.notifications_none
                            : Icons.markunread,
                      ),
                      title: Text(jsonText(item, 'title')),
                      subtitle: Text(
                        '${jsonText(item, 'content')}\n${jsonText(item, 'createdAt')}',
                      ),
                      onTap: _busy ? null : () => _read(item),
                    ),
                  ),
              ],
            ),
    ),
  );
}
