

import 'package:meubcars/Data/Dtos/AssuranceDto.dart';
import 'package:meubcars/Data/remote/AssurancesRemote.dart';

abstract class IAssurancesRepository {
  Future<List<AssuranceDto>> list({int? voitureId});
  Future<AssuranceDto> get(int id);
  Future<AssuranceDto> create(AssuranceDto dto);
  Future<void> update(int id, AssuranceDto dto);
  Future<void> delete(int id);
  Future<AssuranceDto> setPrincipal(int id, int pieceJointeId);
  Future<AssuranceDto> unsetPrincipal(int id);
}

class AssurancesRepository implements IAssurancesRepository {
  final AssurancesRemote remote;
  AssurancesRepository(this.remote);

  @override
  Future<List<AssuranceDto>> list({int? voitureId}) => remote.list(voitureId: voitureId);
  @override
  Future<AssuranceDto> get(int id) => remote.get(id);
  @override
  Future<AssuranceDto> create(AssuranceDto dto) => remote.create(dto);
  @override
  Future<void> update(int id, AssuranceDto dto) => remote.update(id, dto);
  @override
  Future<void> delete(int id) => remote.delete(id);
  @override
  Future<AssuranceDto> setPrincipal(int id, int pieceJointeId) => remote.setPrincipal(id, pieceJointeId);
  @override
  Future<AssuranceDto> unsetPrincipal(int id) => remote.unsetPrincipal(id);
}
