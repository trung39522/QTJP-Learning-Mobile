import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/qtjp_colors.dart';
import '../auth/account_form_screen.dart';
import 'profile_editor_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final base = Uri.tryParse(app.api.baseUrl);
    final avatar = base?.resolve(app.user?['avatarUrl']?.toString() ?? '');
    final avatarValid =
        app.isAuthenticated &&
        (app.user?['avatarUrl']?.toString().isNotEmpty ?? false) &&
        avatar != null &&
        base != null &&
        ['https', 'http'].contains(base.scheme) &&
        ['https', 'http'].contains(avatar.scheme) &&
        avatar.origin == base.origin;
    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: QTJPColors.softBlue,
                    foregroundImage: avatarValid
                        ? NetworkImage(avatar.toString())
                        : null,
                    onForegroundImageError: avatarValid ? (_, _) {} : null,
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 48,
                      color: QTJPColors.navy,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    app.isAuthenticated
                        ? 'Xin chào, ${app.username}'
                        : 'Hành trình của bạn',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: QTJPColors.navyDark,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    app.isAuthenticated
                        ? 'Bạn đã kết nối tài khoản website. Bộ thẻ, bài ngữ pháp và tiến độ flashcard sử dụng chung backend QTJP.'
                        : 'Đăng nhập để tải bộ thẻ, học ngữ pháp và lưu tiến độ bằng tài khoản QTJP Learning.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: QTJPColors.muted,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (app.isAuthenticated) ...[
                    Chip(
                      label: Text(
                        'Gói tài khoản: ${app.user?['membership'] ?? 'FREE'}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: const Text('Nâng cấp / gia hạn VIP'),
                      onTap: () => Navigator.pushNamed(context, AppRoutes.vip),
                    ),
                    ListTile(
                      leading: const Icon(Icons.auto_awesome),
                      title: const Text('Hỏi trợ lý AI Kyuto'),
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.assistant),
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Chỉnh sửa hồ sơ'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ProfileEditorScreen(),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.password),
                      title: const Text('Đổi mật khẩu'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AccountFormScreen(
                            form: AccountForm.password,
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.devices),
                      title: const Text('Thiết bị đăng nhập'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AccountSessionsScreen(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => app.logout(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Đăng xuất'),
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('profile-login'),
                        onPressed: app.restoring
                            ? null
                            : () =>
                                  Navigator.of(context)
                                      .pushNamed(AppRoutes.login),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Đăng nhập'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (app.restoring) const LinearProgressIndicator(),
                  if (app.sessionNotice != null) ...[
                    Text(app.sessionNotice!),
                    if (!app.isAuthenticated && app.supportsRememberSession)
                      TextButton(
                        onPressed: app.restoring ? null : app.restoreSession,
                        child: const Text('Thử khôi phục phiên'),
                      ),
                  ],
                  Text(
                    app.isAuthenticated
                        ? app.rememberSession
                              ? 'Phiên được giữ trong kho bảo mật của thiết bị. Không lưu mật khẩu.'
                              : 'Phiên chỉ lưu trong bộ nhớ; đóng hẳn ứng dụng cần đăng nhập lại.'
                        : 'Bạn đang khám phá ứng dụng với tư cách khách.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: QTJPColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Máy chủ dữ liệu',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: QTJPColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    app.api.baseUrl.isEmpty
                        ? 'Chưa cấu hình API_BASE_URL'
                        : base?.replace(userInfo: '').toString() ??
                              'Cấu hình máy chủ không hợp lệ',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: QTJPColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bản phát triển qua USB cần backend trên máy tính đang chạy. Bảng chữ cái và nét viết vẫn dùng được ngoại tuyến.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: QTJPColors.muted,
                      height: 1.6,
                      fontSize: 12,
                    ),
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
