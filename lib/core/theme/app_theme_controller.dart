import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ThemePreferenceStore {
  Future<String?> read();
  Future<void> write(String mode);
}

class SecureThemePreferenceStore implements ThemePreferenceStore {
  const SecureThemePreferenceStore();
  static const _storage = FlutterSecureStorage();
  static const _key = 'qtjp.appearance.v1';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String mode) => _storage.write(key: _key, value: mode);
}

class AppThemeController extends ChangeNotifier {
  AppThemeController({this.store, ThemeMode initialMode = ThemeMode.light})
    : _mode = initialMode;
  final ThemePreferenceStore? store;
  ThemeMode _mode;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;
  int _revision = 0;
  bool _disposed = false;
  Future<void> _pendingWrite = Future.value();

  Future<void> restore() async {
    final revision = _revision;
    try {
      final value = await store?.read();
      if (_disposed ||
          revision != _revision ||
          !['light', 'dark'].contains(value)) {
        return;
      }
      _mode = value == 'dark' ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (_) {
      // A preference failure must not block sign-in or app startup.
    }
  }

  void toggle() => setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  void setMode(ThemeMode value) {
    if (_disposed || value == ThemeMode.system || _mode == value) return;
    _revision++;
    _mode = value;
    notifyListeners();
    // Serialize rapid toggles. This key is independent of the auth session.
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        await store?.write(value == ThemeMode.dark ? 'dark' : 'light');
      } catch (_) {
        /* Keep the selected appearance for this run. */
      }
    });
  }

  Future<void> get pendingWrite => _pendingWrite;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppThemeScope extends InheritedNotifier<AppThemeController> {
  const AppThemeScope({
    required AppThemeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);
  static AppThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppThemeScope>()?.notifier;
}
