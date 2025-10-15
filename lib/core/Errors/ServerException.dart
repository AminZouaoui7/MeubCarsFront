import 'package:dio/dio.dart';

import 'errorModel.dart';

class ServerException implements Exception{
  final ErrorModel errorModel;

  ServerException({required this.errorModel});



}

