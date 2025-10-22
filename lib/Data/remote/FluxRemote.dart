import 'package:dio/dio.dart';
import 'package:meubcars/core/api/api_consumer.dart';
import 'package:meubcars/Data/Dtos/FluxTransportDto.dart';

class FluxRemote {
  final ApiConsumer api;
  FluxRemote(this.api);

  Future<List<FluxTransportDto>> list({
    required int voitureId,
    DateTime? from,
    DateTime? to,
  }) async {
    final qp = {
      'voitureId': voitureId,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    };
    final res = await api.get('/FluxTransports', queryParameters: qp);
    return (res as List).map((e) => FluxTransportDto.fromJson(e)).toList();
  }

  Future<FluxTransportDto> get(int id) async =>
      FluxTransportDto.fromJson(await api.get('/FluxTransports/$id'));

  Future<FluxTransportDto> create(FluxTransportDto dto) async =>
      FluxTransportDto.fromJson(await api.post('/FluxTransports', data: dto.toJson(), options: Options(contentType: 'application/json')));

  Future<void> update(int id, FluxTransportDto dto) async =>
      api.put('/FluxTransports/$id', data: dto.toJson());

  Future<void> delete(int id) async => api.delete('/FluxTransports/$id');
}
