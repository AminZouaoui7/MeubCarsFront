import 'package:dio/dio.dart';
import 'package:meubcars/Core/Cache/cacheHelper.dart';
import 'package:meubcars/Core/api/api_consumer.dart';
import 'package:meubcars/Core/api/endpoints.dart';

class DioConsumer implements ApiConsumer {
  final Dio dio;

  DioConsumer({Dio? dio})
      : dio = dio ??
      Dio(BaseOptions(
        baseUrl: EndPoint.baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        // ❌ Do NOT set a global Content-Type here
      )) {
    print("📌 Dio baseUrl : ${this.dio.options.baseUrl}");
  }

  // ----- headers builders -----
  Future<String?> _getToken() async =>
      (await CacheHelper.getData(key: 'token'))?.toString();

  Future<Options> _authOnly() async {
    final token = await _getToken();
    return Options(headers: {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      // no Content-Type here -> lets Dio set it (JSON/multipart/etc.)
    });
  }

  Future<Options> _authJson() async {
    final base = await _authOnly();
    // merge headers with JSON content-type
    final merged = Map<String, dynamic>.from(base.headers ?? {})
      ..['Content-Type'] = 'application/json';
    return base.copyWith(headers: merged);
  }

  // util
  void _logSuccess(String method, Response r) =>
      print("✅ $method ${r.requestOptions.uri} → ${r.statusCode}\n📦 ${r.data}");
  void _logError(String method, DioException e) =>
      print("❌ $method ${e.requestOptions.uri}\n   ${e.message}");

  // ----- HTTP -----
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final opts = await _authOnly();
      final r = await dio.get(path, queryParameters: queryParameters, options: opts);
      _logSuccess("GET", r);
      return r.data;
    } on DioException catch (e) {
      _logError("GET", e);
      rethrow;
    }
  }

  @override
  Future<dynamic> post(String path, {Object? data, Options? options, Map<String, dynamic>? queryParameters}) async {
    try {
      options ??= await (data is FormData ? _authOnly() : _authJson());
      final r = await dio.post(path, data: data, queryParameters: queryParameters, options: options);
      _logSuccess("POST", r);
      return r.data;
    } on DioException catch (e) {
      _logError("POST", e);
      rethrow;
    }
  }

  @override
  Future<dynamic> put(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      options ??= await (data is FormData ? _authOnly() : _authJson());
      final r = await dio.put(path, data: data, queryParameters: queryParameters, options: options);
      _logSuccess("PUT", r);
      return r.data;
    } on DioException catch (e) {
      _logError("PUT", e);
      rethrow;
    }
  }

  @override
  Future<dynamic> patch(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      options ??= await (data is FormData ? _authOnly() : _authJson());
      final r = await dio.patch(path, data: data, queryParameters: queryParameters, options: options);
      _logSuccess("PATCH", r);
      return r.data;
    } on DioException catch (e) {
      _logError("PATCH", e);
      rethrow;
    }
  }

  @override
  Future<dynamic> delete(String path, {Object? data, Map<String, dynamic>? queryParameters}) async {
    try {
      final opts = await _authOnly();
      final r = await dio.delete(path, data: data, queryParameters: queryParameters, options: opts);
      _logSuccess("DELETE", r);
      return r.data;
    } on DioException catch (e) {
      _logError("DELETE", e);
      rethrow;
    }
  }
}
