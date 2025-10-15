

import 'package:meubcars/Data/Dtos/VignetteDto.dart';
import 'package:meubcars/Data/remote/VignettesRemote.dart';

abstract class IVignettesRepository {
  Future<List<VignetteDto>> list({int? voitureId});
  Future<VignetteDto> get(int id);
  Future<VignetteDto> create(VignetteDto dto);
  Future<void> update(int id, VignetteDto dto);
  Future<void> delete(int id);
  Future<VignetteDto> setPrincipal(int id, int pieceJointeId);
  Future<VignetteDto> unsetPrincipal(int id);
}

class VignettesRepository implements IVignettesRepository {
  final VignettesRemote remote;
  VignettesRepository(this.remote);

  @override
  Future<List<VignetteDto>> list({int? voitureId}) => remote.list(voitureId: voitureId);
  @override
  Future<VignetteDto> get(int id) => remote.get(id);
  @override
  Future<VignetteDto> create(VignetteDto dto) => remote.create(dto);
  @override
  Future<void> update(int id, VignetteDto dto) => remote.update(id, dto);
  @override
  Future<void> delete(int id) => remote.delete(id);
  @override
  Future<VignetteDto> setPrincipal(int id, int pieceJointeId) => remote.setPrincipal(id, pieceJointeId);
  @override
  Future<VignetteDto> unsetPrincipal(int id) => remote.unsetPrincipal(id);
}
