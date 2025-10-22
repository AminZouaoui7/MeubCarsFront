import 'package:meubcars/core/cache/CacheHelper.dart';

class AuthStore {
  static const _kToken = 'token';

  static Future<bool> isLoggedIn() async {
    final t = CacheHelper.getData(key: _kToken);
    return t != null && t.toString().isNotEmpty;
  }

  static Future<String?> token() async {
    final t = CacheHelper.getData(key: _kToken);
    return t?.toString();
  }

  static Future<void> logout() async {
    await CacheHelper.removeData(key: _kToken);
  }
}
