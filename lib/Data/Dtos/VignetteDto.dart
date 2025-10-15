// vignette_dto.dart

import 'package:meubcars/Data/Dtos/DocumentCoutBaseDto.dart';

class VignetteDto extends DocumentCoutBaseDto {
  final int? anneeFiscale;
  final String? numeroQuittance;

  VignetteDto({
    required super.id,
    required super.voitureId,
    super.dateDebut,
    super.dateFin,
    super.montant,
    super.datePaiement,
    super.dateProchainPaiement,
    super.fichierUrl,
    super.notes,
    this.anneeFiscale,
    this.numeroQuittance,
  });

  factory VignetteDto.fromJson(Map<String, dynamic> j) {
    final b = DocumentCoutBaseDto.fromJson(j);
    return VignetteDto(
      id: b.id, voitureId: b.voitureId,
      dateDebut: b.dateDebut, dateFin: b.dateFin, montant: b.montant,
      datePaiement: b.datePaiement, dateProchainPaiement: b.dateProchainPaiement,
      fichierUrl: b.fichierUrl, notes: b.notes,
      anneeFiscale: j['anneeFiscale'] as int?,
      numeroQuittance: j['numeroQuittance'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    if (anneeFiscale != null) 'anneeFiscale': anneeFiscale,
    if (numeroQuittance != null) 'numeroQuittance': numeroQuittance,
  };
}
