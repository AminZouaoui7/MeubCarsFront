import 'package:dio/dio.dart';
import 'package:meubcars/core/api/api_consumer.dart';
import 'package:meubcars/Data/Dtos/SocieteDto.dart';

class SocietesRemote {
  final ApiConsumer api;
  static  Options _json = Options(contentType: 'application/json');

  SocietesRemote(this.api);

  Future<List<SocieteDto>> list() async {
    final res = await api.get('/Societes');
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(SocieteDto.fromJson).toList();
    // ou: return list.map((e) => SocieteDto.fromJson(e)).toList();
  }

  Future<SocieteDto> getById(int id) async {
    final res = await api.get('/Societes/$id');
    return SocieteDto.fromJson(res as Map<String, dynamic>);
  }

  Future<SocieteDto> create(SocieteDto dto) async {
    final res = await api.post('/Societes', data: dto.toJson(), options: _json);
    return SocieteDto.fromJson(res as Map<String, dynamic>);
  }

  Future<void> update(int id, SocieteDto dto) async {
    await api.put('/Societes/$id', data: dto.toJson(), options: _json);
  }

  Future<void> delete(int id) async {
    await api.delete('/Societes/$id');
  }

}
