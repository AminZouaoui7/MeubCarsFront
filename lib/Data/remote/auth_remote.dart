import 'package:dio/dio.dart';
import 'package:meubcars/Data/Dtos/login_response.dart';
import 'package:meubcars/core/api/endpoints.dart';

class AuthRemote {
  final Dio _dio;

  AuthRemote({Dio? dio})
      : _dio = dio ??
      Dio(
        BaseOptions(
          baseUrl: EndPoint.baseUrl, // ex: https://localhost:7178/api
          responseType: ResponseType.json,
          // Do not throw on 4xx/3xx automatically; we’ll handle it.
          validateStatus: (s) => s != null && s >= 200 && s < 500,
        ),
      );

  // Build an API path safely (prevents //)
  String _p(String path) {
    // baseUrl should already include /api; pass only `Auth/login` etc.
    if (path.startsWith('/')) path = path.substring(1);
    return '/$path';
  }

  Future<LoginResponse> login({
    required String cin,
    required String motDePasse,
  }) async {
    final r = await _dio.post(
      _p('Auth/login'),
      data: {'cin': cin, 'motDePasse': motDePasse},
      options: Options(headers: {'Accept': 'application/json, text/plain, */*'}),
    );

    if (r.statusCode == null || r.statusCode! >= 400) {
      throw DioException(
        requestOptions: r.requestOptions,
        response: r,
        type: DioExceptionType.badResponse,
        error: 'Login failed (${r.statusCode})',
      );
    }
    return LoginResponse.fromAny(r.data);
  }

  Future<Map<String, dynamic>> me(String token) async {
    final r = await _dio.get(
      _p('Auth/me'),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode == null || r.statusCode! >= 400) {
      throw DioException(
        requestOptions: r.requestOptions,
        response: r,
        type: DioExceptionType.badResponse,
        error: 'Me failed (${r.statusCode})',
      );
    }
    final data = r.data;
    if (data is Map) return data.cast<String, dynamic>();
    throw const FormatException('Invalid /Auth/me payload');
  }

  Future<void> logout(String token) async {
    final r = await _dio.post(
      _p('Auth/logout'),
      options: Options(headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json, text/plain, */*',
      }),
    );

    // If token is expired, server may return 401 -> we still proceed client-side.
    if (r.statusCode != null && r.statusCode! >= 500) {
      throw DioException(
        requestOptions: r.requestOptions,
        response: r,
        type: DioExceptionType.badResponse,
        error: 'Logout failed (${r.statusCode})',
      );
    }
  }

  Future<Map<String, dynamic>> getUserById(String token, int id) async {
    final r = await _dio.get(
      _p('Utilisateurs/$id'),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode == null || r.statusCode! >= 400) {
      throw DioException(
        requestOptions: r.requestOptions,
        response: r,
        type: DioExceptionType.badResponse,
        error: 'Get user by id failed (${r.statusCode})',
      );
    }
    final data = r.data;
    if (data is Map) return data.cast<String, dynamic>();
    throw const FormatException('Invalid /Utilisateurs/{id} payload');
  }
}
