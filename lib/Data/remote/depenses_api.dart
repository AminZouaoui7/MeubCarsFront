import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/core/cache/CacheHelper.dart';
import 'package:meubcars/Data/Models/TotalDepenses.dart';

class DepensesApi {
  DepensesApi({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(baseUrl: EndPoint.baseUrl));

  final Dio _dio;

  Map<String, String> _auth() {
    final token = CacheHelper.getData<String>(key: 'token');
    return (token == null || token.isEmpty) ? {} : {'Authorization': 'Bearer $token'};
  }

  // Construit le chemin en ajoutant /api/ si nécessaire, sans doubler ni supprimer /api
  String _api(String path) {
    // Supprime slash au début
    path = path.startsWith('/') ? path.substring(1) : path;

    // NE PAS rajouter "api/" si baseUrl se termine déjà par /api
    return path; // baseUrl: http://localhost:7178/api => .../api/depenses/total
  }

  /// Total global de toutes les voitures
  Future<TotalDepenses> fetchTotalGlobal() async {
    final path = _api('depenses/total');
    final res = await _dio.get(path, options: Options(headers: _auth()));

    // LOG pour diagnostiquer un 404
    debugPrint('[DepensesApi] GET ${res.requestOptions.uri} -> ${res.statusCode}');

    if (res.statusCode != 200) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: 'HTTP ${res.statusCode}',
      );
    }
    return TotalDepenses.fromJson(res.data as Map<String, dynamic>);
  }
}
