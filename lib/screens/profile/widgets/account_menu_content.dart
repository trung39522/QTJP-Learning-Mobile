import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/qtjp_colors.dart';
import '../../../core/widgets/appearance_tile.dart';
import '../../auth/account_repository.dart';
import '../../home/widgets/home_account_avatar.dart';
import '../models/account_presentation.dart';

class AccountMenuContent extends StatefulWidget {
  const AccountMenuContent({required this.onClose, super.key});
  final Future<void> Function() onClose;
  @override
  State<AccountMenuContent> createState() => _AccountMenuContentState();
}

class _AccountMenuContentState extends State<AccountMenuContent> {
  late AppController _app;
  int? _session;
  bool _loading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    if (_session != _app.api.sessionVersion) {
      _session = _app.api.sessionVersion;
      _loading = false;
      _error = null;
      if (_app.isAuthenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_refresh());
        });
      }
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
      }
    } catch (_) {
      if (mounted && session == _app.api.sessionVersion) {
        setState(() => _error = 'Chưa đồng bộ được hồ sơ.');
      }
    } finally {
      if (mounted && session == _app.api.sessionVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(String route) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final app = _app;
    await widget.onClose();
    if (!navigator.mounted) return;
    final result = await navigator.pushNamed(route);
    if (route == AppRoutes.register &&
        result is String &&
        navigator.mounted &&
        !app.isAuthenticated) {
      await navigator.pushNamed(AppRoutes.login);
    }
  }

  Future<void> _logout() async {
    final app = _app;
    await widget.onClose();
    unawaited(app.logout());
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountPresentation(_app.user);
    final vip = account.vipAt(DateTime.now());
    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        key: const ValueKey('account-menu-scroll'),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const HomeAccountAvatar(radius: 16, plain: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _app.isAuthenticated
                            ? account.name
                            : 'Chào mừng đến QTJP',
                        key: const ValueKey('account-menu-name'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.qtjp.heading,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _app.isAuthenticated
                            ? account.statusAt(DateTime.now())
                            : 'Đăng nhập để tiếp tục hành trình học',
                        style: TextStyle(
                          color: vip
                              ? const Color(0xFFAD8100)
                              : context.qtjp.muted,
                          fontSize: 11,
                          fontWeight: vip ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(height: 12),
            if (_app.restoring) const LinearProgressIndicator(),
            if (_app.isAuthenticated) ...[
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_error != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: context.qtjp.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              _item(
                'Hồ sơ',
                Icons.person_outline_rounded,
                () => _open(AppRoutes.profile),
              ),
              _item(
                'Bảo mật',
                Icons.lock_outline_rounded,
                () => _open(AppRoutes.security),
              ),
              _item(
                'Nâng cấp VIP',
                Icons.workspace_premium_outlined,
                () => _open(AppRoutes.vip),
              ),
              _item(
                'Góp ý & Báo lỗi',
                Icons.feedback_outlined,
                () => _open(AppRoutes.feedback),
              ),
              const AppearanceTile(compact: true),
              const Divider(height: 12),
              _item(
                'Đăng xuất',
                Icons.logout_rounded,
                _logout,
                destructive: true,
              ),
            ] else ...[
              _item(
                'Đăng nhập',
                Icons.login_rounded,
                _app.restoring ? null : () => _open(AppRoutes.login),
              ),
              _item(
                'Đăng ký',
                Icons.person_add_alt_1_outlined,
                _app.restoring ? null : () => _open(AppRoutes.register),
              ),
              const Divider(height: 12),
              const AppearanceTile(compact: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _item(
    String title,
    IconData icon,
    VoidCallback? action, {
    bool destructive = false,
  }) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : context.qtjp.heading;
    return ListTile(
      key: ValueKey('account-menu-$title'),
      dense: true,
      minTileHeight: 44,
      minVerticalPadding: 4,
      horizontalTitleGap: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: action,
    );
  }
}
