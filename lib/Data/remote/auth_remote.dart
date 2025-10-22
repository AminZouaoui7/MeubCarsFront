// lib/Data/remote/auth_remote.dart
import 'package:dio/dio.dart';
import 'package:meubcars/Data/Dtos/login_response.dart';
import 'package:meubcars/core/api/endpoints.dart';

class AuthRemote {
  final Dio dio;

  AuthRemote({Dio? custom})
      : dio = custom ??
      Dio(
        BaseOptions(
          baseUrl: EndPoint.baseUrl,
          responseType: ResponseType.json,
          validateStatus: (s) => s != null && s >= 200 && s < 500,
        ),
      );

  String _path(String p) => p.startsWith('/') ? p : '/$p';

  Future<LoginResponse> login({
    required String cin,
    required String motDePasse,
  }) async {
    final r = await dio.post(
      _path('Auth/login'),
      data: {'cin': cin, 'motDePasse': motDePasse},
      options: Options(headers: {'Accept': 'application/json'}),
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
    final r = await dio.get(
      _path('Auth/me'),
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
    if (r.data is Map) return Map<String, dynamic>.from(r.data);
    throw const FormatException('Invalid /Auth/me response');
  }

  Future<void> logout(String token) async {
    final r = await dio.post(
      _path('Auth/logout'),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
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
    final r = await dio.get(
      _path('Utilisateurs/$id'),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (r.statusCode == null || r.statusCode! >= 400) {
      throw DioException(
        requestOptions: r.requestOptions,
        response: r,
        type: DioExceptionType.badResponse,
        error: 'Get user failed (${r.statusCode})',
      );
    }
    if (r.data is Map) return Map<String, dynamic>.from(r.data);
    throw const FormatException('Invalid /Utilisateurs/{id} response');
  }
}
