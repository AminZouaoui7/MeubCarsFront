import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:meubcars/core/cache/cacheHelper.dart';
import 'package:meubcars/core/api/api_consumer.dart';
import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/utils/AppSideMenu.dart';

class DioConsumer implements ApiConsumer {
  final Dio dio;
  final GlobalKey<NavigatorState>? navigatorKey;
  static GlobalKey<NavigatorState>? defaultNavigatorKey;
  bool _handlingUnauthorized = false;

  DioConsumer({Dio? dio, this.navigatorKey})
      : dio = dio ?? Dio(
    BaseOptions(
      baseUrl: EndPoint.baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
    ),
  ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final t = _getToken(); // ✅ pas d'await
          if (t != null) options.headers['Authorization'] = 'Bearer $t';
          options.headers['Accept'] = 'application/json';
          handler.next(options);
        },
        onResponse: (r, handler) => handler.next(r),
        onError: (e, handler) async {
          final code = e.response?.statusCode ?? 0;
          if ((code == 401 || code == 403) && !_handlingUnauthorized) {
            _handlingUnauthorized = true;
            try {
              await _clearAuth();
              final key = navigatorKey ?? defaultNavigatorKey;
              final ctx = key?.currentContext;
              if (ctx != null) {
                Navigator.of(ctx).pushNamedAndRemoveUntil(
                  AppRoutes.login,
                      (route) => false,
                  arguments: {'from': e.requestOptions.path},
                );
              }
            } finally {
              _handlingUnauthorized = false;
            }
          }
          handler.next(e);
        },
      ),
    );
  }

  // --- Token depuis SharedPreferences (synchrone)
  String? _getToken() {
    final raw = CacheHelper.getData(key: 'token');
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null' || s == '0') return null;
    return s;
  }

  Future<void> _clearAuth() async {
    await CacheHelper.removeData(key: 'token');
    await CacheHelper.removeData(key: 'user');
    await CacheHelper.removeData(key: 'userId');
    await CacheHelper.removeData(key: 'userName');
    await CacheHelper.removeData(key: 'nomComplet');
    await CacheHelper.removeData(key: 'email');
    await CacheHelper.removeData(key: 'telephone');
    await CacheHelper.removeData(key: 'cin');
    await CacheHelper.removeData(key: 'role');
    await CacheHelper.removeData(key: 'societeId');
  }

  Future<Options> _authOnly() async {
    final t = _getToken();
    return Options(headers: {
      if (t != null) 'Authorization': 'Bearer $t',
      'Accept': 'application/json',
    });
  }

  Future<Options> _authJson() async {
    final base = await _authOnly();
    final merged = Map<String, dynamic>.from(base.headers ?? {})
      ..['Content-Type'] = 'application/json';
    return base.copyWith(headers: merged);
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final opts = await _authOnly();
    final r = await dio.get(path, queryParameters: queryParameters, options: opts);
    return r.data;
  }

  @override
  Future<dynamic> post(String path, {Object? data, Options? options, Map<String, dynamic>? queryParameters}) async {
    options ??= await (data is FormData ? _authOnly() : _authJson());
    final r = await dio.post(path, data: data, queryParameters: queryParameters, options: options);
    return r.data;
  }

  @override
  Future<dynamic> put(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options}) async {
    options ??= await (data is FormData ? _authOnly() : _authJson());
    final r = await dio.put(path, data: data, queryParameters: queryParameters, options: options);
    return r.data;
  }

  @override
  Future<dynamic> patch(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options}) async {
    options ??= await (data is FormData ? _authOnly() : _authJson());
    final r = await dio.patch(path, data: data, queryParameters: queryParameters, options: options);
    return r.data;
  }

  @override
  Future<dynamic> delete(String path, {Object? data, Map<String, dynamic>? queryParameters}) async {
    final opts = await _authOnly();
    final r = await dio.delete(path, data: data, queryParameters: queryParameters, options: opts);
    return r.data;
  }
}
