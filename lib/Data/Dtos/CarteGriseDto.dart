// carte_grise_dto.dart
import 'package:meubcars/Data/Dtos/DocumentCoutBaseDto.dart';


class CarteGriseDto extends DocumentCoutBaseDto {
  final String? numeroCarte;
  final String? proprietaireLegal;

  CarteGriseDto({
    required super.id,
    required super.voitureId,
    super.dateDebut,
    super.dateFin,
    super.montant,
    super.datePaiement,
    super.dateProchainPaiement,
    super.fichierUrl,
    super.notes,
    this.numeroCarte,
    this.proprietaireLegal,
  });

  factory CarteGriseDto.fromJson(Map<String, dynamic> j) {
    final b = DocumentCoutBaseDto.fromJson(j);
    return CarteGriseDto(
      id: b.id, voitureId: b.voitureId,
      dateDebut: b.dateDebut, dateFin: b.dateFin, montant: b.montant,
      datePaiement: b.datePaiement, dateProchainPaiement: b.dateProchainPaiement,
      fichierUrl: b.fichierUrl, notes: b.notes,
      numeroCarte: j['numeroCarte'] as String?,
      proprietaireLegal: j['proprietaireLegal'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    if (numeroCarte != null) 'numeroCarte': numeroCarte,
    if (proprietaireLegal != null) 'proprietaireLegal': proprietaireLegal,
  };
}
