import 'package:dio/dio.dart';
import 'package:meubcars/core/api/api_consumer.dart';
import 'package:meubcars/Data/Dtos/CarteGriseDto.dart';

class CartesGrisesRemote {
  final ApiConsumer api;
  CartesGrisesRemote(this.api);

  Future<List<CarteGriseDto>> list({int? voitureId}) async {
    final res = await api.get('/CartesGrises', queryParameters: {
      if (voitureId != null) 'voitureId': voitureId,
    });
    return (res as List).map((e) => CarteGriseDto.fromJson(e)).toList();
  }

  Future<CarteGriseDto> get(int id) async =>
      CarteGriseDto.fromJson(await api.get('/CartesGrises/$id'));

  Future<CarteGriseDto> create(CarteGriseDto dto) async =>
      CarteGriseDto.fromJson(await api.post('/CartesGrises', data: dto.toJson(), options: Options(contentType: 'application/json')));

  Future<void> update(int id, CarteGriseDto dto) async =>
      api.put('/CartesGrises/$id', data: dto.toJson());

  Future<void> delete(int id) async => api.delete('/CartesGrises/$id');

  Future<CarteGriseDto> setPrincipal(int id, int pieceJointeId) async =>
      CarteGriseDto.fromJson(await api.put('/CartesGrises/$id/definir-principal', data: {'pieceJointeId': pieceJointeId}));

  Future<CarteGriseDto> unsetPrincipal(int id) async =>
      CarteGriseDto.fromJson(await api.put('/CartesGrises/$id/retirer-principal'));
}
