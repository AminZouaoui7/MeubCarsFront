import 'package:meubcars/Data/Dtos/SocieteDto.dart';
import 'package:meubcars/Data/remote/SocietesRemote.dart';

abstract class ISocietesRepository {
  Future<List<SocieteDto>> list();
  Future<SocieteDto> getById(int id);   // ✅ renommé pour correspondre
  Future<SocieteDto> create(SocieteDto dto);
  Future<void> update(int id, SocieteDto dto);
  Future<void> delete(int id);
}

class SocietesRepository implements ISocietesRepository {
  final SocietesRemote remote;
  SocietesRepository(this.remote);

  @override
  Future<List<SocieteDto>> list() => remote.list();

  @override
  Future<SocieteDto> getById(int id) => remote.getById(id); // ✅ cohérent

  @override
  Future<SocieteDto> create(SocieteDto dto) => remote.create(dto);

  @override
  Future<void> update(int id, SocieteDto dto) => remote.update(id, dto);

  @override
  Future<void> delete(int id) => remote.delete(id);
}
