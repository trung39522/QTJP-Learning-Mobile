import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/network/api_client.dart';
import '../core/storage/session_store.dart';

class AppController extends ChangeNotifier {
  AppController({ApiClient? api, this.sessionStore})
    : api = api ?? ApiClient() {
    this.api.onUnauthorized = _expire;
  }
  final ApiClient api;
  final SessionStore? sessionStore;
  Future<void> _storageWork = Future.value();
  bool _disposed = false;
  bool restoring = false;
  bool rememberSession = false;
  String? sessionNotice;
  bool get supportsRememberSession => sessionStore != null;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _user != null && api.token != null;
  String get username => _user?['username']?.toString() ?? '';
  int _generation = 0;

  Future<void> login(
    String username,
    String password, {
    bool replaceOtherSession = false,
    bool remember = false,
  }) => _signIn('/api/users/login', {
    'username': username.trim(),
    'password': password,
    'replaceOtherSession': replaceOtherSession,
  }, remember: remember);

  Future<void> loginWithGoogle(
    String credential, {
    bool replaceOtherSession = false,
    bool remember = false,
  }) => _signIn('/api/users/google-login', {
    'credential': credential,
    'replaceOtherSession': replaceOtherSession,
  }, remember: remember);

  Future<void> _signIn(
    String path,
    Map<String, dynamic> body, {
    required bool remember,
  }) async {
    final generation = ++_generation;
    if (restoring) {
      // An explicit login supersedes restore, even when that login fails. Do
      // not leave an unverified restored token or a permanent loading state.
      restoring = false;
      api.token = null;
      notifyListeners();
    }
    final data = jsonObject(await api.request('POST', path, body: body));
    if (generation != _generation) return;
    final token = data['token'];
    if (token is! String || token.isEmpty || data['id'] == null) {
      throw const ApiException('Máy chủ không trả phiên đăng nhập hợp lệ.');
    }
    api.token = token;
    _user = Map.unmodifiable({...data}..remove('token'));
    rememberSession = remember && supportsRememberSession;
    restoring = false;
    sessionNotice = null;
    notifyListeners();
    await _persist(rememberSession ? token : null);
  }

  Future<void> _persist(String? token) {
    final store = sessionStore;
    if (store == null) return Future.value();
    final session = api.sessionVersion;
    // Serialize writes/deletes so a slow login write cannot resurrect a token
    // after sign-out. No plain-text fallback if the platform store is locked.
    _storageWork = _storageWork.then((_) async {
      try {
        if (token == null) {
          await store.clear();
        } else {
          await store.write(api.baseUrl, token);
        }
      } catch (_) {
        if (!_disposed && session == api.sessionVersion) {
          if (token != null) rememberSession = false;
          sessionNotice = 'Không thể giữ đăng nhập trên thiết bị này. Bạn vẫn có thể tiếp tục học.';
          notifyListeners();
        }
      }
    });
    return _storageWork;
  }

  Future<void> restoreSession() async {
    if (sessionStore == null || restoring || isAuthenticated) return;
    final generation = ++_generation;
    restoring = true;
    sessionNotice = null;
    notifyListeners();
    try {
      await _storageWork;
      final token = await sessionStore!.read(api.baseUrl);
      if (_disposed || generation != _generation || token == null) return;
      api.token = token;
      final profile = jsonObject(
        await api.get('/api/users/me/profile', authenticated: true),
      );
      if (_disposed || generation != _generation) return;
      if (profile['id'] == null || jsonText(profile, 'username').isEmpty) {
        throw const ApiException('Máy chủ chưa xác nhận được tài khoản.');
      }
      _user = Map.unmodifiable({...profile}..remove('token'));
      rememberSession = true;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        api.token = null;
        _user = null;
        sessionNotice = 'Chưa khôi phục được phiên. Bạn có thể thử lại khi có mạng hoặc đăng nhập bằng mật khẩu.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        restoring = false;
        notifyListeners();
      }
    }
  }

  void updateProfile(Map<String, dynamic> data) {
    if (!isAuthenticated || data['id'] != _user?['id']) {
      throw const ApiException('Hồ sơ không thuộc phiên hiện tại.');
    }
    _user = Map.unmodifiable({...data}..remove('token'));
    notifyListeners();
  }

  Future<void> logout() async {
    // Initiate the request with the old token, then immediately clear local data.
    final request = api.token == null
        ? null
        : api.request('POST', '/api/users/logout', authenticated: true);
    _expire();
    try {
      await request;
    } on ApiException {
      // Local sign-out must also work when the server is offline.
    }
    await _storageWork;
  }

  void _expire() {
    _generation++;
    api.token = null;
    _user = null;
    rememberSession = false;
    restoring = false;
    unawaited(_persist(null));
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    _disposed = true;
    api.onUnauthorized = null;
    api.token = null;
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    required AppController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);
  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
