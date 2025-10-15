import 'package:dio/dio.dart';
import 'package:meubcars/core/api/api_consumer.dart';
import 'package:meubcars/Data/Dtos/VignetteDto.dart';

class VignettesRemote {
  final ApiConsumer api;
  VignettesRemote(this.api);

  Future<List<VignetteDto>> list({int? voitureId}) async {
    final res = await api.get('/Vignettes', queryParameters: {
      if (voitureId != null) 'voitureId': voitureId,
    });
    return (res as List).map((e) => VignetteDto.fromJson(e)).toList();
  }

  Future<VignetteDto> get(int id) async =>
      VignetteDto.fromJson(await api.get('/Vignettes/$id'));

  Future<VignetteDto> create(VignetteDto dto) async =>
      VignetteDto.fromJson(await api.post('/Vignettes', data: dto.toJson(), options: Options(contentType: 'application/json')));

  Future<void> update(int id, VignetteDto dto) async =>
      api.put('/Vignettes/$id', data: dto.toJson());

  Future<void> delete(int id) async => api.delete('/Vignettes/$id');

  Future<VignetteDto> setPrincipal(int id, int pieceJointeId) async =>
      VignetteDto.fromJson(await api.put('/Vignettes/$id/definir-principal', data: {'pieceJointeId': pieceJointeId}));

  Future<VignetteDto> unsetPrincipal(int id) async =>
      VignetteDto.fromJson(await api.put('/Vignettes/$id/retirer-principal'));
}
