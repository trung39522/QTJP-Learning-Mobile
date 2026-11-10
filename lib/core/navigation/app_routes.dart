/// Route identifiers shared by screens, without coupling them to the router.
abstract final class AppRoutes {
  static const login = '/login';
  static const profile = '/profile';
  static const assistant = '/assistant';
  static const notifications = '/notifications';
  static const vip = '/vip';

  static String feature(String id, {required String level}) =>
      Uri(path: '/learn/$id', queryParameters: {'level': level}).toString();
}
