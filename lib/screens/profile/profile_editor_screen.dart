import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import '../auth/account_repository.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key});
  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  final _email = TextEditingController(), _phone = TextEditingController();
  final _form = GlobalKey<FormState>();
  late AppController _app;
  late int _owner;
  bool _bound = false, _loaded = false, _busy = false;
  String? _message;
  bool get _valid => _app.isAuthenticated && _app.api.sessionVersion == _owner;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    if (!_bound) {
      _bound = true;
      _owner = _app.api.sessionVersion;
      unawaited(_load());
    }
    if (!_valid) {
      _email.clear();
      _phone.clear();
      _message = null;
    }
  }

  Future<void> _run(
    Future<void> Function(AccountRepository repo) action,
  ) async {
    if (_busy || !_valid) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action(AccountRepository(_app.api));
    } catch (error) {
      if (mounted && _valid) {
        setState(
          () => _message = error is ApiException
              ? error.message
              : 'Chưa cập nhật được hồ sơ. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run((repo) async {
    final profile = await repo.profile();
    if (!mounted || !_valid) return;
    _app.updateProfile(profile);
    _email.text = jsonText(profile, 'email');
    _phone.text = jsonText(profile, 'phone');
    _loaded = true;
  });
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await _run((repo) async {
      final profile = await repo.saveProfile(_email.text, _phone.text);
      if (!mounted || !_valid) return;
      _app.updateProfile(profile);
      _message = 'Đã cập nhật hồ sơ.';
    });
  }

  Future<void> _avatar() => _run((repo) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (picked == null || !mounted || !_valid) return;
    final bytes = await picked.readAsBytes();
    if (!mounted || !_valid) return;
    final profile = await repo.avatar(bytes);
    if (!mounted || !_valid) return;
    _app.updateProfile(profile);
    _message = 'Đã cập nhật ảnh đại diện.';
  });
  Future<void> _removeAvatar() async {
    if (_busy || !_valid) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa ảnh đại diện?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa ảnh'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted || !_valid) return;
    await _run((repo) async {
      final profile = await repo.removeAvatar();
      if (mounted && _valid) {
        _app.updateProfile(profile);
        _message = 'Đã xóa ảnh đại diện.';
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chỉnh sửa hồ sơ')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: !_valid
                ? const Text(
                    'Phiên tài khoản đã thay đổi. Quay lại Cá nhân để mở hồ sơ hiện tại.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_busy) const LinearProgressIndicator(),
                      if (_message != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(_message!),
                        ),
                      if (!_loaded)
                        OutlinedButton(
                          onPressed: _busy ? null : _load,
                          child: const Text('Tải hồ sơ'),
                        ),
                      if (_loaded)
                        Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Tên đăng nhập: ${_app.username}'),
                              const SizedBox(height: 20),
                              TextFormField(
                                key: const ValueKey('profile-email'),
                                controller: _email,
                                enabled: !_busy,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                ),
                                validator: (value) =>
                                    validateEmail(value ?? ''),
                              ),
                              TextFormField(
                                key: const ValueKey('profile-phone'),
                                controller: _phone,
                                enabled: !_busy,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Số điện thoại',
                                ),
                                validator: (value) =>
                                    validatePhone(value ?? ''),
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                key: const ValueKey('profile-save'),
                                onPressed: _busy ? null : _save,
                                child: const Text('Lưu hồ sơ'),
                              ),
                              OutlinedButton(
                                onPressed: _busy ? null : _avatar,
                                child: const Text(
                                  'Chọn ảnh đại diện từ thư viện',
                                ),
                              ),
                              if (jsonText(_app.user!, 'avatarUrl').isNotEmpty)
                                TextButton(
                                  onPressed: _busy ? null : _removeAvatar,
                                  child: const Text('Xóa ảnh đại diện'),
                                ),
                            ],
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

class AccountSessionsScreen extends StatefulWidget {
  const AccountSessionsScreen({super.key});
  @override
  State<AccountSessionsScreen> createState() => _AccountSessionsScreenState();
}

class _AccountSessionsScreenState extends State<AccountSessionsScreen> {
  late AppController _app;
  late int _owner;
  bool _bound = false, _busy = false;
  List<Map<String, dynamic>> _sessions = [];
  String? _error;
  bool get _valid => _app.isAuthenticated && _owner == _app.api.sessionVersion;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    if (!_bound) {
      _bound = true;
      _owner = _app.api.sessionVersion;
      unawaited(_load());
    }
    if (!_valid) _sessions = [];
  }

  Future<void> _load() async {
    if (_busy || !_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sessions = await AccountRepository(_app.api).sessions();
      if (mounted && _valid) setState(() => _sessions = sessions);
    } catch (error) {
      if (mounted && _valid) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Chưa tải được danh sách thiết bị.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    if (_busy || !_valid) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất các thiết bị khác?'),
        content: const Text(
          'Phiên hiện tại vẫn được giữ. Các thiết bị khác cần đăng nhập lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất thiết bị khác'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted || !_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AccountRepository(_app.api).revokeOthers();
    } catch (error) {
      if (mounted && _valid) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Chưa đăng xuất được thiết bị khác.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && _valid && _error == null) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thiết bị đăng nhập')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!_valid)
            const Text('Phiên đã thay đổi. Mở lại danh sách từ Cá nhân.')
          else ...[
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            for (final session in _sessions)
              ListTile(
                title: Text(jsonText(session, 'device')),
                subtitle: Text(jsonText(session, 'createdAt')),
                trailing: session['current'] == true
                    ? const Text('Thiết bị này')
                    : null,
              ),
            OutlinedButton(
              onPressed: _busy ? null : _load,
              child: const Text('Tải lại thiết bị'),
            ),
            FilledButton(
              onPressed: _busy ? null : _revoke,
              child: const Text('Đăng xuất thiết bị khác'),
            ),
          ],
        ],
      ),
    ),
  );
}
