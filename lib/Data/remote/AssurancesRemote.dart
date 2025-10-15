import 'package:dio/dio.dart';
import 'package:meubcars/core/api/api_consumer.dart';
import 'package:meubcars/Data/Dtos/AssuranceDto.dart';

class AssurancesRemote {
  final ApiConsumer api;
  AssurancesRemote(this.api);

  Future<List<AssuranceDto>> list({int? voitureId}) async {
    final res = await api.get('/Assurances', queryParameters: {
      if (voitureId != null) 'voitureId': voitureId,
    });
    return (res as List).map((e) => AssuranceDto.fromJson(e)).toList();
  }

  Future<AssuranceDto> get(int id) async =>
      AssuranceDto.fromJson(await api.get('/Assurances/$id'));

  Future<AssuranceDto> create(AssuranceDto dto) async =>
      AssuranceDto.fromJson(await api.post('/Assurances', data: dto.toJson(), options: Options(contentType: 'application/json')));

  Future<void> update(int id, AssuranceDto dto) async =>
      api.put('/Assurances/$id', data: dto.toJson());

  Future<void> delete(int id) async => api.delete('/Assurances/$id');

  Future<AssuranceDto> setPrincipal(int id, int pieceJointeId) async =>
      AssuranceDto.fromJson(await api.put('/Assurances/$id/definir-principal', data: {'pieceJointeId': pieceJointeId}));

  Future<AssuranceDto> unsetPrincipal(int id) async =>
      AssuranceDto.fromJson(await api.put('/Assurances/$id/retirer-principal'));
}
