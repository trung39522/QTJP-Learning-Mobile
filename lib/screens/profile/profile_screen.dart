import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../assistant/kyuto_assistant_host.dart';

import '../../app/app_controller.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/qtjp_colors.dart';
import '../../core/widgets/appearance_tile.dart';
import '../auth/account_form_screen.dart';
import '../home/widgets/home_account_avatar.dart';
import 'models/account_presentation.dart';
import 'profile_editor_screen.dart';
import 'widgets/account_settings_group.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final account = AccountPresentation(app.user);
    final email = app.user?['email']?.toString().trim() ?? '';
    return KyutoScaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    key: const ValueKey('profile-summary'),
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: context.qtjp.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: context.qtjp.border),
                    ),
                    child: Row(
                      children: [
                        const HomeAccountAvatar(radius: 30, plain: true),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.isAuthenticated
                                    ? 'Xin chào, ${account.name}'
                                    : 'Chào mừng bạn',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.qtjp.heading,
                                  fontSize: 18,
                                  height: 1.3,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (app.isAuthenticated) ...[
                                const SizedBox(height: 7),
                                Text(
                                  account.statusAt(DateTime.now()),
                                  style: TextStyle(
                                    color: account.vipAt(DateTime.now())
                                        ? const Color(0xFFB58C0A)
                                        : context.qtjp.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (email.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: context.qtjp.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ] else
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Lưu tiến độ học tập của bạn.',
                                    style: TextStyle(
                                      color: context.qtjp.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (app.isAuthenticated) ...[
                    AccountSettingsGroup(
                      title: 'TÀI KHOẢN',
                      children: [
                        AccountSettingTile(
                          title: 'Chỉnh sửa hồ sơ',
                          subtitle: 'Ảnh đại diện và thông tin cá nhân',
                          icon: Icons.person_outline_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const ProfileEditorScreen(),
                            ),
                          ),
                        ),
                        AccountSettingTile(
                          title: 'Nâng cấp / gia hạn VIP',
                          subtitle: 'Quản lý gói thành viên',
                          icon: Icons.workspace_premium_outlined,
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.vip),
                        ),
                      ],
                    ),
                    AccountSettingsGroup(
                      title: 'BẢO MẬT',
                      children: [
                        AccountSettingTile(
                          title: 'Đổi mật khẩu',
                          icon: Icons.lock_outline_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const AccountFormScreen(
                                form: AccountForm.password,
                              ),
                            ),
                          ),
                        ),
                        AccountSettingTile(
                          title: 'Thiết bị đăng nhập',
                          icon: Icons.devices_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const AccountSessionsScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    FilledButton.icon(
                      key: const ValueKey('profile-login'),
                      onPressed: app.restoring
                          ? null
                          : () => Navigator.pushNamed(context, AppRoutes.login),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Đăng nhập'),
                    ),
                    TextButton(
                      onPressed: app.restoring
                          ? null
                          : () async {
                              final navigator = Navigator.of(context);
                              final result = await navigator.pushNamed(
                                AppRoutes.register,
                              );
                              if (navigator.mounted &&
                                  result is String &&
                                  !app.isAuthenticated) {
                                await navigator.pushNamed(AppRoutes.login);
                              }
                            },
                      child: const Text('Tạo tài khoản mới'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  AccountSettingsGroup(
                    title: 'CÀI ĐẶT',
                    children: [
                      const AppearanceTile(),
                      AccountSettingTile(
                        title: 'Hỏi trợ lý AI Kyuto',
                        icon: Icons.auto_awesome_outlined,
                        onTap: () => KyutoAssistantScope.show(context),
                      ),
                    ],
                  ),
                  if (app.restoring) const LinearProgressIndicator(),
                  if (app.sessionNotice != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        app.sessionNotice!,
                        style: TextStyle(
                          color: context.qtjp.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (!app.isAuthenticated &&
                      app.sessionNotice != null &&
                      app.supportsRememberSession)
                    TextButton(
                      onPressed: app.restoring ? null : app.restoreSession,
                      child: const Text('Thử đăng nhập lại'),
                    ),
                  if (app.isAuthenticated)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error
                              .withValues(alpha: .35),
                        ),
                      ),
                      onPressed: () => app.logout(),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text('Đăng xuất'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
