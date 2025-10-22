import 'package:meubcars/Data/Dtos/VoitureDto.dart';
import 'package:meubcars/Data/remote/VoituresRemote.dart';


abstract class IVoituresRepository {
  Future<List<VoitureDto>> list();
  Future<VoitureDto> get(int id);
  Future<VoitureDto> create(Map<String, dynamic> body);
  Future<void> update(int id, Map<String, dynamic> body);
  Future<void> delete(int id);
  Future<void> affecterSociete(int voitureId, int societeId);
  Future<void> desaffecterSociete(int voitureId);
}

class VoituresRepository implements IVoituresRepository {
  final VoituresRemote remote;
  VoituresRepository(this.remote);

  @override
  Future<List<VoitureDto>> list() => remote.list();
  @override
  Future<VoitureDto> get(int id) => remote.get(id);
  @override
  Future<VoitureDto> create(Map<String, dynamic> body) => remote.create(body);
  @override
  Future<void> update(int id, Map<String, dynamic> body) => remote.update(id, body);
  @override
  Future<void> delete(int id) => remote.delete(id);
  @override
  Future<void> affecterSociete(int voitureId, int societeId) => remote.affecterSociete(voitureId, societeId);
  @override
  Future<void> desaffecterSociete(int voitureId) => remote.desaffecterSociete(voitureId);
}
