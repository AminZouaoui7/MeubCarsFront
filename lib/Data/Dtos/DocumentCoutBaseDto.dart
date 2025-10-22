// base_document_cout_dto.dart
// _json.dart – petits utilitaires
DateTime? _dt(dynamic v) => v == null ? null : DateTime.parse(v as String);
T? _opt<T>(Map m, String k) => m[k] as T?;

class DocumentCoutBaseDto {
  final int id;
  final int voitureId;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final double? montant;
  final DateTime? datePaiement;
  final DateTime? dateProchainPaiement;
  final String? fichierUrl;
  final String? notes;

  DocumentCoutBaseDto({
    required this.id,
    required this.voitureId,
    this.dateDebut,
    this.dateFin,
    this.montant,
    this.datePaiement,
    this.dateProchainPaiement,
    this.fichierUrl,
    this.notes,
  });

  factory DocumentCoutBaseDto.fromJson(Map<String, dynamic> j) => DocumentCoutBaseDto(
    id: j['id'] as int,
    voitureId: j['voitureId'] as int,
    dateDebut: _dt(j['dateDebut']),
    dateFin: _dt(j['dateFin']),
    montant: j['montant'] == null ? null : (j['montant'] as num).toDouble(),
    datePaiement: _dt(j['datePaiement']),
    dateProchainPaiement: _dt(j['dateProchainPaiement']),
    fichierUrl: j['fichierUrl'] as String?,
    notes: j['notes'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'voitureId': voitureId,
    if (dateDebut != null) 'dateDebut': dateDebut!.toIso8601String(),
    if (dateFin != null) 'dateFin': dateFin!.toIso8601String(),
    if (montant != null) 'montant': montant,
    if (datePaiement != null) 'datePaiement': datePaiement!.toIso8601String(),
    if (dateProchainPaiement != null) 'dateProchainPaiement': dateProchainPaiement!.toIso8601String(),
    if (fichierUrl != null) 'fichierUrl': fichierUrl,
    if (notes != null) 'notes': notes,
  };
}
