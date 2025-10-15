
import 'package:meubcars/Data/Dtos/FluxTransportDto.dart';
import 'package:meubcars/Data/remote/FluxRemote.dart';

abstract class IFluxRepository {
  Future<List<FluxTransportDto>> list({required int voitureId, DateTime? from, DateTime? to});
  Future<FluxTransportDto> get(int id);
  Future<FluxTransportDto> create(FluxTransportDto dto);
  Future<void> update(int id, FluxTransportDto dto);
  Future<void> delete(int id);
}

class FluxRepository implements IFluxRepository {
  final FluxRemote remote;
  FluxRepository(this.remote);

  @override
  Future<List<FluxTransportDto>> list({required int voitureId, DateTime? from, DateTime? to}) =>
      remote.list(voitureId: voitureId, from: from, to: to);

  @override
  Future<FluxTransportDto> get(int id) => remote.get(id);

  @override
  Future<FluxTransportDto> create(FluxTransportDto dto) => remote.create(dto);

  @override
  Future<void> update(int id, FluxTransportDto dto) => remote.update(id, dto);

  @override
  Future<void> delete(int id) => remote.delete(id);
}
