// assurance_dto.dart

import 'package:meubcars/Data/Dtos/DocumentCoutBaseDto.dart';

class AssuranceDto extends DocumentCoutBaseDto {
  final String? compagnie;
  final String? numeroPolice;
  final bool? tousRisques;

  AssuranceDto({
    required super.id,
    required super.voitureId,
    super.dateDebut,
    super.dateFin,
    super.montant,
    super.datePaiement,
    super.dateProchainPaiement,
    super.fichierUrl,
    super.notes,
    this.compagnie,
    this.numeroPolice,
    this.tousRisques,
  });

  factory AssuranceDto.fromJson(Map<String, dynamic> j) {
    final base = DocumentCoutBaseDto.fromJson(j);
    return AssuranceDto(
      id: base.id,
      voitureId: base.voitureId,
      dateDebut: base.dateDebut,
      dateFin: base.dateFin,
      montant: base.montant,
      datePaiement: base.datePaiement,
      dateProchainPaiement: base.dateProchainPaiement,
      fichierUrl: base.fichierUrl,
      notes: base.notes,
      compagnie: j['compagnie'] as String?,
      numeroPolice: j['numeroPolice'] as String?,
      tousRisques: j['tousRisques'] as bool?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    if (compagnie != null) 'compagnie': compagnie,
    if (numeroPolice != null) 'numeroPolice': numeroPolice,
    if (tousRisques != null) 'tousRisques': tousRisques,
  };
}
