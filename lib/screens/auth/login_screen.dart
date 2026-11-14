import 'package:flutter/material.dart';

import '../../core/widgets/kyuto_scaffold.dart';

import '../../core/theme/qtjp_colors.dart';
import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import 'account_form_screen.dart';
import 'google_identity.dart';
import 'google_mark.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({this.googleIdentity, super.key});
  final GoogleIdentity? googleIdentity;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;
  bool _remember = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final app = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      try {
        await app.login(
          _usernameController.text,
          _passwordController.text,
          remember: _remember,
        );
      } on ApiException catch (error) {
        if (error.code != 'VIP_SESSION_ACTIVE' || !mounted) rethrow;
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Tài khoản đang được sử dụng'),
            content: Text(
              '${error.message}\n\nBạn có muốn đăng xuất phiên trên thiết bị khác để tiếp tục không?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Tiếp tục đăng nhập'),
              ),
            ],
          ),
        );
        if (replace != true || !mounted) return;
        await app.login(
          _usernameController.text,
          _passwordController.text,
          replaceOtherSession: true,
          remember: _remember,
        );
      }
      if (!mounted) return;
      _passwordController.clear();
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Chưa thể đăng nhập. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAccount(AccountForm form) async {
    if (_busy) return;
    final username = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => AccountFormScreen(form: form)),
    );
    if (mounted) {
      _passwordController.clear();
      if (username != null) _usernameController.text = username;
    }
  }

  Future<void> _submitGoogle() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final app = AppScope.of(context);
    final session = app.api.sessionVersion;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final credential = await (widget.googleIdentity ?? DeviceGoogleIdentity())
          .credential();
      if (!mounted || credential == null || session != app.api.sessionVersion) {
        return;
      }
      try {
        await app.loginWithGoogle(credential, remember: _remember);
      } on ApiException catch (error) {
        if (error.code != 'VIP_SESSION_ACTIVE' || !mounted) rethrow;
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Tài khoản đang được sử dụng'),
            content: Text(
              '${error.message}\n\nBạn có muốn đăng xuất phiên trên thiết bị khác để tiếp tục không?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Tiếp tục đăng nhập'),
              ),
            ],
          ),
        );
        if (replace != true || !mounted || session != app.api.sessionVersion) {
          return;
        }
        await app.loginWithGoogle(
          credential,
          replaceOtherSession: true,
          remember: _remember,
        );
      }
      if (!mounted) return;
      _passwordController.clear();
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Chưa thể đăng nhập Google. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: context.qtjp.surface,
    errorMaxLines: 3,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.qtjp.border),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return KyutoScaffold(
      showAssistant: false,
      appBar: AppBar(title: const Text('Tài khoản QTJP')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/auth/auth_background.jpg',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
          ColoredBox(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xB30C1423)
                : const Color(0x8CE1E8FF),
          ),
          SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 32).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 470),
                      padding: EdgeInsets.all(
                        constraints.maxWidth < 360 ? 20 : 28,
                      ),
                      decoration: BoxDecoration(
                        color: context.qtjp.surface.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: context.qtjp.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x2E14235A),
                            blurRadius: 40,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Image.asset(
                                'assets/branding/qtjp_logo.png',
                                height: 56,
                                semanticLabel: 'QTJP Learning',
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Đăng nhập',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.qtjp.heading,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Học tiếng Nhật mỗi ngày',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: context.qtjp.muted),
                            ),
                            const SizedBox(height: 16),
                            const SizedBox(height: 8),
                            TextFormField(
                              key: const ValueKey('login-username'),
                              controller: _usernameController,
                              enabled: !_busy,
                              decoration: _decoration(
                                'Tên đăng nhập',
                                Icons.person_outline_rounded,
                              ),
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              textCapitalization: TextCapitalization.none,
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Vui lòng nhập tên đăng nhập.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const ValueKey('login-password'),
                              controller: _passwordController,
                              enabled: !_busy,
                              obscureText: _obscurePassword,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.done,
                              decoration:
                                  _decoration(
                                    'Mật khẩu',
                                    Icons.lock_outline_rounded,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword
                                          ? 'Hiện mật khẩu'
                                          : 'Ẩn mật khẩu',
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Vui lòng nhập mật khẩu.'
                                  : null,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            if (AppScope.of(context).supportsRememberSession)
                              CheckboxListTile(
                                value: _remember,
                                onChanged: _busy
                                    ? null
                                    : (value) => setState(
                                        () => _remember = value ?? false,
                                      ),
                                title: const Text(
                                  'Lưu đăng nhập',
                                  style: TextStyle(fontSize: 12),
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                visualDensity: VisualDensity.compact,
                                checkboxScaleFactor: .8,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    _openAccount(AccountForm.forgot),
                                child: const Text('Quên mật khẩu?'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF173F78),
                                    Color(0xFF496AB5),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: FilledButton(
                                key: const ValueKey('login-submit'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                ),
                                onPressed: _busy ? null : _submit,
                                child: Text(
                                  _busy ? 'Đang đăng nhập…' : 'Vào học ngay',
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _error!,
                                  key: const ValueKey('login-error'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: context.qtjp.heading,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              key: const ValueKey('login-google'),
                              onPressed: _busy ? null : _submitGoogle,
                              icon: const GoogleMark(),
                              label: const Text(
                                'Đăng nhập bằng Google',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Chưa có tài khoản?',
                                  style: TextStyle(color: context.qtjp.muted),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _openAccount(AccountForm.register),
                                  child: const Text('Đăng ký ngay'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
