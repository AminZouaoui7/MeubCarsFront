import 'package:dio/dio.dart';
import 'package:meubcars/core/api/api_consumer.dart';
import 'package:meubcars/Data/Dtos/PieceJointeDto.dart';

class PiecesRemote {
  final ApiConsumer api;
  PiecesRemote(this.api);

  Future<List<PieceJointeDto>> list(int voitureId) async {
    final res = await api.get('/voitures/$voitureId/pieces-jointes');
    return (res as List).map((e) => PieceJointeDto.fromJson(e)).toList();
  }

  Future<PieceJointeDto> upload(int voitureId, {required MultipartFile file, String? titre}) async {
    final form = FormData.fromMap({'file': file, if (titre != null) 'titre': titre});
    final res = await api.post('/voitures/$voitureId/pieces-jointes/upload',
        data: form, options: Options(contentType: 'multipart/form-data'));
    return PieceJointeDto.fromJson(res);
  }

  Future<PieceJointeDto> createFromUrl(int voitureId, {required String fichierUrl, String? titre, String? typeMime}) async {
    final res = await api.post('/voitures/$voitureId/pieces-jointes/from-url',
        data: {'fichierUrl': fichierUrl, if (titre != null) 'titre': titre, if (typeMime != null) 'typeMime': typeMime}, options: Options(contentType: 'application/json'));
    return PieceJointeDto.fromJson(res);
  }

  Future<PieceJointeDto> get(int voitureId, int pieceId) async {
    final res = await api.get('/voitures/$voitureId/pieces-jointes/$pieceId');
    return PieceJointeDto.fromJson(res);
  }

  Future<void> delete(int voitureId, int pieceId) async =>
      api.delete('/voitures/$voitureId/pieces-jointes/$pieceId');
}
