import 'package:dio/dio.dart';
import 'package:meubcars/core/api/api_consumer.dart';
import 'package:meubcars/Data/Dtos/VoitureDto.dart';

class VoituresRemote {
  final ApiConsumer api;
  VoituresRemote(this.api);

  Future<List<VoitureDto>> list() async {
    final res = await api.get('/Voitures');
    return (res as List).map((e) => VoitureDto.fromJson(e)).toList();
  }

  Future<VoitureDto> get(int id) async {
    final res = await api.get('/Voitures/$id');
    return VoitureDto.fromJson(res);
  }

  Future<VoitureDto> create(Map<String, dynamic> body) async {
    final res = await api.post('/Voitures', data: body,options: Options(contentType: 'application/json'),
    );
    return VoitureDto.fromJson(res);
  }

  Future<void> update(int id, Map<String, dynamic> body) async {
    await api.put('/Voitures/$id', data: body);
  }

  Future<void> delete(int id) async {
    await api.delete('/Voitures/$id');
  }

  Future<void> affecterSociete(int voitureId, int societeId) =>
      api.put('/Voitures/$voitureId/affecter-societe', data: {'societeId': societeId});

  Future<void> desaffecterSociete(int voitureId) =>
      api.put('/Voitures/$voitureId/desaffecter-societe');
}
