import 'package:shared_preferences/shared_preferences.dart';

class CacheHelper {
  static late SharedPreferences _prefs;

  /// Must be called once at app startup
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Save data
  static Future<bool> saveData({required String key, required dynamic value}) async {
    if (value is bool) return _prefs.setBool(key, value);
    if (value is String) return _prefs.setString(key, value);
    if (value is int) return _prefs.setInt(key, value);
    if (value is double) return _prefs.setDouble(key, value);
    throw Exception("Unsupported type: ${value.runtimeType}");
  }

  // Get data (generic)
  static T? getData<T>({required String key}) {
    final v = _prefs.get(key);
    return v as T?;
  }

  // Remove data
  static Future<bool> removeData({required String key}) async {
    return _prefs.remove(key);
  }

  // Check key
  static bool containsKey(String key) {
    return _prefs.containsKey(key);
  }

  // Clear everything
  static Future<bool> clearData() async {
    return _prefs.clear();
  }
}
