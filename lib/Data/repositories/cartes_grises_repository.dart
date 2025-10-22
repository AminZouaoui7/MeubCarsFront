import 'package:meubcars/Data/Dtos/CarteGriseDto.dart';
import 'package:meubcars/Data/remote/CartesGrisesRemote.dart';


abstract class ICartesGrisesRepository {
  Future<List<CarteGriseDto>> list({int? voitureId});
  Future<CarteGriseDto> get(int id);
  Future<CarteGriseDto> create(CarteGriseDto dto);
  Future<void> update(int id, CarteGriseDto dto);
  Future<void> delete(int id);
  Future<CarteGriseDto> setPrincipal(int id, int pieceJointeId);
  Future<CarteGriseDto> unsetPrincipal(int id);
}

class CartesGrisesRepository implements ICartesGrisesRepository {
  final CartesGrisesRemote remote;
  CartesGrisesRepository(this.remote);

  @override
  Future<List<CarteGriseDto>> list({int? voitureId}) => remote.list(voitureId: voitureId);
  @override
  Future<CarteGriseDto> get(int id) => remote.get(id);
  @override
  Future<CarteGriseDto> create(CarteGriseDto dto) => remote.create(dto);
  @override
  Future<void> update(int id, CarteGriseDto dto) => remote.update(id, dto);
  @override
  Future<void> delete(int id) => remote.delete(id);
  @override
  Future<CarteGriseDto> setPrincipal(int id, int pieceJointeId) => remote.setPrincipal(id, pieceJointeId);
  @override
  Future<CarteGriseDto> unsetPrincipal(int id) => remote.unsetPrincipal(id);
}
