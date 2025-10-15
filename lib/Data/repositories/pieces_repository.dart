

import 'package:meubcars/Data/Dtos/PieceJointeDto.dart';
import 'package:meubcars/Data/remote/PiecesRemote.dart';

abstract class IPiecesRepository {
  Future<List<PieceJointeDto>> list(int voitureId);
  Future<PieceJointeDto> get(int voitureId, int pieceId);
  // upload: passe par Remote (MultipartFile)
  Future<void> delete(int voitureId, int pieceId);
}

class PiecesRepository implements IPiecesRepository {
  final PiecesRemote remote;
  PiecesRepository(this.remote);

  @override
  Future<List<PieceJointeDto>> list(int voitureId) => remote.list(voitureId);

  @override
  Future<PieceJointeDto> get(int voitureId, int pieceId) => remote.get(voitureId, pieceId);

  @override
  Future<void> delete(int voitureId, int pieceId) => remote.delete(voitureId, pieceId);
}
