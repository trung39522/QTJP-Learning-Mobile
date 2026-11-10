import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import 'account_repository.dart';

enum AccountForm { register, forgot, reset, password }

class AccountFormScreen extends StatefulWidget {
  const AccountFormScreen({required this.form, super.key});
  final AccountForm form;
  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController(),
      _token = TextEditingController(),
      _current = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  bool _busy = false, _done = false;
  String? _error;
  int? _owner;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (widget.form == AccountForm.password) {
      _owner ??= app.api.sessionVersion;
      if (_owner != app.api.sessionVersion) _clearSecrets();
    }
  }

  String get _title => switch (widget.form) {
    AccountForm.register => 'Đăng ký',
    AccountForm.forgot => 'Quên mật khẩu',
    AccountForm.reset => 'Đặt lại mật khẩu',
    AccountForm.password => 'Đổi mật khẩu',
  };
  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final app = AppScope.of(context);
    final session = app.api.sessionVersion;
    if (widget.form == AccountForm.password && _owner != session) return;
    final repo = AccountRepository(app.api);
    setState(() {
      _busy = true;
      _error = null;
    });
    FocusScope.of(context).unfocus();
    try {
      switch (widget.form) {
        case AccountForm.register:
          await repo.register(
            _username.text,
            _email.text,
            _phone.text,
            _password.text,
            _confirm.text,
          );
        case AccountForm.forgot:
          await repo.forgot(_email.text);
        case AccountForm.reset:
          await repo.reset(_token.text, _password.text, _confirm.text);
        case AccountForm.password:
          await repo.password(_current.text, _password.text, _confirm.text);
          if (session == app.api.sessionVersion) await app.logout();
      }
      if (mounted) {
        _clearSecrets();
        setState(() => _done = true);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Chưa hoàn thành yêu cầu. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearSecrets() {
    _password.clear();
    _confirm.clear();
    _current.clear();
    _token.clear();
  }

  @override
  void dispose() {
    for (final controller in [
      _username,
      _email,
      _phone,
      _token,
      _current,
      _password,
      _confirm,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String key, {
    bool secret = false,
    String? Function(String)? validator,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      enabled: !_busy,
      obscureText: secret,
      autocorrect: false,
      enableSuggestions: !secret,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        errorMaxLines: 3,
      ),
      validator: (value) =>
          validator?.call(value ?? '') ??
          ((value ?? '').trim().isEmpty ? 'Vui lòng nhập $label.' : null),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_title)),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _done
                ? Column(
                    children: [
                      Text(switch (widget.form) {
                        AccountForm.register => 'Tạo tài khoản thành công. Hãy đăng nhập bằng tài khoản vừa tạo.',
                        AccountForm.forgot => 'Nếu email tồn tại trong hệ thống, liên kết đặt lại mật khẩu đã được gửi. Hãy kiểm tra cả thư rác.',
                        _ => 'Đổi mật khẩu thành công. Vui lòng đăng nhập lại.',
                      }, style: const TextStyle(height: 1.7)),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          context,
                          widget.form == AccountForm.register
                              ? _username.text.trim()
                              : null,
                        ),
                        child: const Text('Quay lại đăng nhập'),
                      ),
                      if (widget.form == AccountForm.forgot)
                        TextButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const AccountFormScreen(
                                form: AccountForm.reset,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Tôi đã có liên kết đặt lại mật khẩu',
                          ),
                        ),
                    ],
                  )
                : widget.form == AccountForm.password &&
                      _owner != AppScope.of(context).api.sessionVersion
                ? const Text(
                    'Phiên tài khoản đã thay đổi. Quay lại Cá nhân để đổi mật khẩu cho tài khoản hiện tại.',
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.form == AccountForm.register)
                          _field(
                            _username,
                            'Tên đăng nhập',
                            'account-username',
                            validator: (s) =>
                                RegExp(r'^[a-zA-Z0-9._]{4,30}$')
                                    .hasMatch(s.trim())
                                ? null
                                : 'Tên đăng nhập 4–30 ký tự: chữ, số, dấu chấm hoặc gạch dưới.',
                          ),
                        if ([
                          AccountForm.register,
                          AccountForm.forgot,
                        ].contains(widget.form))
                          _field(
                            _email,
                            'Email',
                            'account-email',
                            validator: validateEmail,
                            keyboard: TextInputType.emailAddress,
                          ),
                        if (widget.form == AccountForm.register)
                          _field(
                            _phone,
                            'Số điện thoại',
                            'account-phone',
                            validator: (s) => validatePhone(s, required: true),
                            keyboard: TextInputType.phone,
                          ),
                        if (widget.form == AccountForm.reset) ...[
                          const Text(
                            'Dán liên kết đặt lại mật khẩu từ email hoặc mã token trong liên kết. Liên kết do backend gửi qua email.',
                          ),
                          const SizedBox(height: 16),
                          _field(
                            _token,
                            'Liên kết hoặc mã đặt lại',
                            'account-token',
                            secret: true,
                          ),
                        ],
                        if (widget.form == AccountForm.password)
                          _field(
                            _current,
                            'Mật khẩu hiện tại',
                            'account-current',
                            secret: true,
                          ),
                        if (widget.form != AccountForm.forgot) ...[
                          _field(
                            _password,
                            'Mật khẩu mới',
                            'account-password',
                            secret: true,
                            validator: validatePassword,
                          ),
                          _field(
                            _confirm,
                            'Nhập lại mật khẩu',
                            'account-confirm',
                            secret: true,
                            validator: (s) =>
                                s == _password.text && s.isNotEmpty
                                ? null
                                : 'Mật khẩu nhập lại không khớp.',
                          ),
                        ],
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              _error!,
                              key: const ValueKey('account-error'),
                            ),
                          ),
                        FilledButton(
                          key: const ValueKey('account-submit'),
                          onPressed: _busy ? null : _submit,
                          child: Text(_busy ? 'Đang xử lý…' : _title),
                        ),
                        if (widget.form == AccountForm.forgot)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => const AccountFormScreen(
                                        form: AccountForm.reset,
                                      ),
                                    ),
                                  ),
                            child: const Text(
                              'Tôi đã có liên kết đặt lại mật khẩu',
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}
