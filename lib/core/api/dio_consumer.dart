import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:meubcars/core/api/api_consumer.dart';
import '../../utils/AppSideMenu.dart';
import '../cache/CacheHelper.dart';
import 'endpoints.dart';

class DioConsumer implements ApiConsumer {
  /// ✅ Always initialized immediately → prevents LateInitializationError
  final Dio dio;

  /// Optional navigator key, used for 401/403 redirects
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Shared global key for static access
  static GlobalKey<NavigatorState>? defaultNavigatorKey;

  bool _handlingUnauthorized = false;

  DioConsumer({Dio? customDio, this.navigatorKey})
      : dio = customDio ??
      Dio(
        BaseOptions(
          baseUrl: EndPoint.baseUrl,
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      ) {
    // ✅ Only add interceptors once
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = _getToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            options.headers['Accept'] = 'application/json';
          } catch (e) {
            debugPrint('⚠️ Interceptor token read error: $e');
          }
          handler.next(options);
        },
        onResponse: (response, handler) => handler.next(response),
        onError: (error, handler) async {
          final code = error.response?.statusCode ?? 0;

          // 🔐 Handle unauthorized or expired token
          if ((code == 401 || code == 403) && !_handlingUnauthorized) {
            _handlingUnauthorized = true;
            try {
              await _clearAuth();

              final key = navigatorKey ?? defaultNavigatorKey;
              final ctx = key?.currentContext;
              if (ctx != null && ctx.mounted) {
                Navigator.of(ctx).pushNamedAndRemoveUntil(
                  AppRoutes.login,
                      (route) => false,
                  arguments: {'from': error.requestOptions.path},
                );
              } else {
                debugPrint('⚠️ Navigator context unavailable for logout redirect');
              }
            } catch (e) {
              debugPrint('❌ Auth redirect error: $e');
            } finally {
              _handlingUnauthorized = false;
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  // ==========================================================
  // 🔹 TOKEN & AUTH HELPERS
  // ==========================================================

  String? _getToken() {
    try {
      final raw = CacheHelper.getData(key: 'token');
      final token = (raw ?? '').toString().trim();
      if (token.isEmpty || token.toLowerCase() == 'null' || token == '0') return null;
      return token;
    } catch (e) {
      debugPrint('⚠️ CacheHelper token read error: $e');
      return null;
    }
  }

  Future<void> _clearAuth() async {
    const keys = [
      'token',
      'user',
      'userId',
      'userName',
      'nomComplet',
      'email',
      'telephone',
      'cin',
      'role',
      'societeId',
    ];
    for (final key in keys) {
      await CacheHelper.removeData(key: key);
    }
  }

  Future<Options> _authOnly() async {
    final t = _getToken();
    return Options(headers: {
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
      'Accept': 'application/json',
    });
  }

  Future<Options> _authJson() async {
    final base = await _authOnly();
    final merged = Map<String, dynamic>.from(base.headers ?? {})
      ..['Content-Type'] = 'application/json';
    return base.copyWith(headers: merged);
  }

  // ==========================================================
  // 🔹 CORE API METHODS
  // ==========================================================
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final opts = await _authOnly();
    final r = await dio.get(path, queryParameters: queryParameters, options: opts);
    return r.data;
  }

  @override
  Future<dynamic> post(
      String path, {
        Object? data,
        Options? options,
        Map<String, dynamic>? queryParameters,
      }) async {
    options ??= await (data is FormData ? _authOnly() : _authJson());
    final r = await dio.post(path, data: data, queryParameters: queryParameters, options: options);
    return r.data;
  }

  @override
  Future<dynamic> put(
      String path, {
        Object? data,
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) async {
    options ??= await (data is FormData ? _authOnly() : _authJson());
    final r = await dio.put(path, data: data, queryParameters: queryParameters, options: options);
    return r.data;
  }

  @override
  Future<dynamic> patch(
      String path, {
        Object? data,
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) async {
    options ??= await (data is FormData ? _authOnly() : _authJson());
    final r = await dio.patch(path, data: data, queryParameters: queryParameters, options: options);
    return r.data;
  }

  @override
  Future<dynamic> delete(
      String path, {
        Object? data,
        Map<String, dynamic>? queryParameters,
      }) async {
    final opts = await _authOnly();
    final r = await dio.delete(path, data: data, queryParameters: queryParameters, options: opts);
    return r.data;


  }
}
//new