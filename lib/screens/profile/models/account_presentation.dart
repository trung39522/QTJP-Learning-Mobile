/// Presentation of the existing user payload; never grants API permissions.
class AccountPresentation {
  const AccountPresentation(this.user);
  final Map<String, dynamic>? user;

  String get name => [user?['fullName'], user?['name'], user?['username']]
      .map((value) => value?.toString().trim() ?? '')
      .firstWhere((value) => value.isNotEmpty, orElse: () => 'Học viên');

  bool vipAt(DateTime now) {
    final expires = DateTime.tryParse(user?['vipExpiresAt']?.toString() ?? '');
    return user?['isVip'] == true ||
        (user?['membership']?.toString().toUpperCase() == 'VIP' &&
            expires != null &&
            expires.isAfter(now));
  }

  String statusAt(DateTime now) =>
      vipAt(now) ? 'Thành viên VIP' : 'Tài khoản miễn phí';

  Uri? avatarUri(String baseUrl) {
    final path = (user?['avatarUrl'] ?? user?['avatar'])?.toString() ?? '';
    if (path.isEmpty) return null;
    try {
      final base = Uri.parse(baseUrl);
      final avatar = base.resolve(path);
      if (['http', 'https'].contains(base.scheme) &&
          ['http', 'https'].contains(avatar.scheme) &&
          avatar.userInfo.isEmpty &&
          avatar.origin == base.origin) {
        return avatar;
      }
    } on FormatException {
      // A malformed image URL falls back to the account initial.
    }
    return null;
  }
}
