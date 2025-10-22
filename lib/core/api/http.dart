import 'package:dio/dio.dart';

Dio buildDio(String baseUrl) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl, // ex: https://meubcars-api.onrender.com/api/
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 20),
    validateStatus: (_) => true, // remonte 4xx/5xx sans throw
    headers: {'Accept': 'application/json'},
  ));

  // Retry UNIQUE pour erreurs réseau (DNS reset / cold start / TLS)
  dio.interceptors.add(InterceptorsWrapper(
    onError: (e, handler) async {
      final isNet =
          e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.unknown ||
              e.error.toString().contains('ERR_CONNECTION_RESET') ||
              e.error.toString().contains('ERR_NAME_NOT_RESOLVED');

      final retried = e.requestOptions.extra['__retried__'] == true;
      if (isNet && !retried) {
        e.requestOptions.extra['__retried__'] = true;
        await Future.delayed(const Duration(milliseconds: 700));
        try {
          final resp = await dio.fetch(e.requestOptions);
          return handler.resolve(resp);
        } catch (_) {}
      }
      return handler.next(e);
    },
  ));

  return dio;
}

Future<void> warmup(Dio dio) async {
  try { await dio.get('health'); } catch (_) {/* best effort */}
}
