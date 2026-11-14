import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/network/api_client.dart';

abstract interface class GoogleIdentity {
  Future<String?> credential();
}

class DeviceGoogleIdentity implements GoogleIdentity {
  static const serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static Future<void>? _initialization;

  @override
  Future<String?> credential() async {
    if (kIsWeb ||
        serverClientId.isEmpty ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform) ||
        (defaultTargetPlatform == TargetPlatform.iOS && iosClientId.isEmpty)) {
      throw const ApiException(
        'Đăng nhập Google chưa khả dụng trên thiết bị này. Bạn có thể đăng nhập bằng mật khẩu.',
      );
    }
    try {
      final google = GoogleSignIn.instance;
      await (_initialization ??= google.initialize(
        serverClientId: serverClientId,
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? iosClientId
            : null,
      ));
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          'Google chưa xác nhận được tài khoản. Vui lòng thử lại.',
        );
      }
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const ApiException(
        'Chưa thể đăng nhập Google trên thiết bị này. Hãy thử lại hoặc dùng tên đăng nhập và mật khẩu.',
      );
    }
  }
}
