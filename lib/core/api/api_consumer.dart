
import 'package:dio/dio.dart';

abstract class ApiConsumer {
  Future<dynamic> get(
      String path, {
        Map<String, dynamic>? queryParameters,
      });

  Future<dynamic> post(
      String path, {
        Object? data,
        required Options options,
        Map<String, dynamic>? queryParameters,
      });

  Future<dynamic> patch(
      String path, {
        Object? data,
        Map<String, dynamic>? queryParameters,
      });

  Future<dynamic> delete(
      String path, {
        Object? data,
        Map<String, dynamic>? queryParameters,
      });

  Future<dynamic> put(
      String path, {
        Object? data,
        Map<String, dynamic>? queryParameters,
        Options? options,
      });
}

