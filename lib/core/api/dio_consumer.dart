import 'package:flutter/material.dart'; // pour GlobalKey / Navigator
import 'package:dio/dio.dart';
import 'package:meubcars/core/cache/cacheHelper.dart';
import 'package:meubcars/core/api/api_consumer.dart';
import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/utils/AppSideMenu.dart';

class DioConsumer implements ApiConsumer {
  final Dio dio;
  final GlobalKey<NavigatorState>? navigatorKey;

  // pour éviter les boucles de redirection multiples
  bool _handlingUnauthorized = false;

  DioConsumer({Dio? dio, this.navigatorKey})
      : dio = dio ??
      Dio(
        BaseOptions(
          baseUrl: EndPoint.baseUrl,
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      ) {
    print("📌 Dio baseUrl : ${this.dio.options.baseUrl}");

    // --- Intercepteur global ---
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final t = await _getToken();
          if (t != null) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          options.headers['Accept'] = 'application/json';
          // ne fixe pas 'Content-Type' ici -> géré par appel (JSON vs FormData)
          handler.next(options);
        },
        onError: (e, handler) async {
          // Log avant traitement
          _logError(e.requestOptions.method, e);

          final code = e.response?.statusCode ?? 0;
          if ((code == 401 || code == 403) && !_handlingUnauthorized) {
            _handlingUnauthorized = true;
            try {
              await _clearAuth();
              // Rediriger vers le login en vidant la stack
              final ctx = navigatorKey?.currentContext;
              if (ctx != null) {
                Navigator.of(ctx).pushNamedAndRemoveUntil(
                  AppRoutes.login,
                      (route) => false,
                  arguments: {'from': e.requestOptions.path},
                );
              }
            } catch (_) {
              // ignore
            } finally {
              // on laisse l’erreur remonter pour info appelant
              _handlingUnauthorized = false;
            }
          }
          handler.next(e);
        },
        onResponse: (r, handler) {
          _logSuccess(r.requestOptions.method, r);
          handler.next(r);
        },
      ),
    );
  }

  // ===== Helpers token/cache =====
  Future<String?> _getToken() async {
    final raw = await CacheHelper.getData(key: 'token');
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

  // ===== Builders d’options (JSON vs FormData) =====
  Future<Options> _authOnly() async {
    final t = await _getToken();
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

  // ===== Logs =====
  void _logSuccess(String method, Response r) {
    print("✅ $method ${r.requestOptions.uri} → ${r.statusCode}");
    // print("📦 ${r.data}"); // décommente si tu veux voir le payload
  }

  void _logError(String method, DioException e) {
    final code = e.response?.statusCode;
    print("❌ $method ${e.requestOptions.uri} → $code\n   ${e.message}");
  }

  // ===== Méthodes HTTP =====
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      // options non obligatoires car intercepteur gère les headers,
      // mais on garde pour compat JSON/Accept si besoin
      final opts = await _authOnly();
      final r = await dio.get(path, queryParameters: queryParameters, options: opts);
      return r.data;
    } on DioException catch (e) {
      rethrow;
    }
  }

  @override
  Future<dynamic> post(String path, {Object? data, Options? options, Map<String, dynamic>? queryParameters}) async {
    try {
      options ??= await (data is FormData ? _authOnly() : _authJson());
      final r = await dio.post(path, data: data, queryParameters: queryParameters, options: options);
      return r.data;
    } on DioException catch (e) {
      rethrow;
    }
  }

  @override
  Future<dynamic> put(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      options ??= await (data is FormData ? _authOnly() : _authJson());
      final r = await dio.put(path, data: data, queryParameters: queryParameters, options: options);
      return r.data;
    } on DioException catch (e) {
      rethrow;
    }
  }

  @override
  Future<dynamic> patch(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      options ??= await (data is FormData ? _authOnly() : _authJson());
      final r = await dio.patch(path, data: data, queryParameters: queryParameters, options: options);
      return r.data;
    } on DioException catch (e) {
      rethrow;
    }
  }

  @override
  Future<dynamic> delete(String path, {Object? data, Map<String, dynamic>? queryParameters}) async {
    try {
      final opts = await _authOnly();
      final r = await dio.delete(path, data: data, queryParameters: queryParameters, options: opts);
      return r.data;
    } on DioException catch (e) {
      rethrow;
    }
  }
}
