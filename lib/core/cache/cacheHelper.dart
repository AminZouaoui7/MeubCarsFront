// lib/core/cache/CacheHelper.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheHelper {
  static SharedPreferences? _prefs;
  static bool _ready = false;

  static bool get isReady => _ready && _prefs != null;

  /// ✅ Must be called once at startup (in main())
  static Future<void> init() async {
    if (_ready && _prefs != null) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _ready = true;
      debugPrint('✅ CacheHelper initialized successfully');
    } catch (e, st) {
      debugPrint('⚠️ CacheHelper init error: $e\n$st');
      _ready = false;
      _prefs = null;
    }
  }

  /// ✅ Save value safely
  static Future<bool> saveData({
    required String key,
    required dynamic value,
  }) async {
    if (!isReady) await init();
    if (_prefs == null) return false;

    if (value is bool) return _prefs!.setBool(key, value);
    if (value is String) return _prefs!.setString(key, value);
    if (value is int) return _prefs!.setInt(key, value);
    if (value is double) return _prefs!.setDouble(key, value);
    throw Exception('Unsupported type: ${value.runtimeType}');
  }

  /// ✅ Safe getter — never throws
  static T? getData<T>({required String key}) {
    final prefs = _prefs;
    if (prefs == null) {
      debugPrint('⚠️ CacheHelper.getData called before init ($key)');
      return null;
    }
    final value = prefs.get(key);
    if (value is T) return value;
    return null;
  }

  /// ✅ Remove specific key
  static Future<bool> removeData({required String key}) async {
    if (!isReady) return false;
    return _prefs?.remove(key) ?? false;
  }

  /// ✅ Check key existence
  static bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }

  /// ✅ Clear all stored data
  static Future<bool> clearData() async {
    return _prefs?.clear() ?? false;
  }
}
