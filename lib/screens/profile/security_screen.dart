import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../../app/app_controller.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/qtjp_colors.dart';
import '../auth/account_form_screen.dart';
import '../auth/account_repository.dart';
import 'profile_editor_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  late AppController _app;
  int? _session;
  bool _loading = false, _verified = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    if (_session != _app.api.sessionVersion) {
      _session = _app.api.sessionVersion;
      _loading = false;
      _verified = false;
      _error = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _app.isAuthenticated) unawaited(_refresh());
      });
    }
  }

  Future<void> _refresh() async {
    if (_loading || !_app.isAuthenticated) return;
    final session = _app.api.sessionVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await AccountRepository(_app.api).profile();
      if (mounted && session == _app.api.sessionVersion) {
        _app.updateProfile(profile);
        _verified = true;
      }
    } catch (_) {
      if (mounted && session == _app.api.sessionVersion) {
        _error = 'Chưa tải được thông tin bảo mật tài khoản.';
      }
    } finally {
      if (mounted && session == _app.api.sessionVersion) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    final googleOnly =
        app.user?['authProvider']?.toString().toUpperCase() == 'GOOGLE';
    return KyutoScaffold(
      appBar: AppBar(title: const Text('Bảo mật')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: !app.isAuthenticated
              ? [
                  const Text('Đăng nhập để quản lý bảo mật tài khoản.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.login),
                    child: const Text('Đăng nhập'),
                  ),
                ]
              : [
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: context.qtjp.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.qtjp.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.qtjp.soft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            color: context.qtjp.blue,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bảo mật tài khoản',
                                style: TextStyle(
                                  color: context.qtjp.heading,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                app.username,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.qtjp.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null) ...[
                    Text(_error!),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Thử lại'),
                    ),
                  ],
                  if (_verified && googleOnly)
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Tài khoản đăng nhập bằng Google'),
                      subtitle: Text(
                        'Mật khẩu của tài khoản này được quản lý qua Google.',
                      ),
                    )
                  else if (_verified)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: context.qtjp.border),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.password_rounded),
                        title: const Text('Đổi mật khẩu'),
                        subtitle: const Text(
                          'Cập nhật mật khẩu cho tài khoản QTJP',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const AccountFormScreen(
                              form: AccountForm.password,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: context.qtjp.border),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.devices_rounded),
                      title: const Text('Thiết bị đăng nhập'),
                      subtitle: const Text(
                        'Xem các phiên và đăng xuất thiết bị khác',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AccountSessionsScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}
