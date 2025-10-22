import 'package:dio/dio.dart';
import '../cache/CacheHelper.dart';

class ApiInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Récupérer le token depuis le cache (assure-toi que le token y est stocké)
    final token = await CacheHelper.getData(key: "token");

    if (token != null) {
      options.headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      });
    }

    super.onRequest(options, handler);
  }
}

 