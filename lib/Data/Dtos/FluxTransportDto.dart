// flux_transport_dto.dart
// base_document_cout_dto.dart
// _json.dart – petits utilitaires
DateTime? _dt(dynamic v) => v == null ? null : DateTime.parse(v as String);
T? _opt<T>(Map m, String k) => m[k] as T?;
class FluxTransportDto {
  final int id;
  final int voitureId;
  final DateTime dateFlux;
  final String? depart;
  final String? destination;
  final String? objet;
  final int? chauffeurId;
  final int? kilometresParcourus;
  final double? cout;
  final String? notes;

  FluxTransportDto({
    required this.id,
    required this.voitureId,
    required this.dateFlux,
    this.depart,
    this.destination,
    this.objet,
    this.chauffeurId,
    this.kilometresParcourus,
    this.cout,
    this.notes,
  });

  factory FluxTransportDto.fromJson(Map<String, dynamic> j) => FluxTransportDto(
    id: j['id'] as int,
    voitureId: j['voitureId'] as int,
    dateFlux: _dt(j['dateFlux']) ?? DateTime.now(),
    depart: j['depart'] as String?,
    destination: j['destination'] as String?,
    objet: j['objet'] as String?,
    chauffeurId: j['chauffeurId'] as int?,
    kilometresParcourus: j['kilometresParcourus'] as int?,
    cout: j['cout'] == null ? null : (j['cout'] as num).toDouble(),
    notes: j['notes'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'voitureId': voitureId,
    'dateFlux': dateFlux.toIso8601String(),
    if (depart != null) 'depart': depart,
    if (destination != null) 'destination': destination,
    if (objet != null) 'objet': objet,
    if (chauffeurId != null) 'chauffeurId': chauffeurId,
    if (kilometresParcourus != null) 'kilometresParcourus': kilometresParcourus,
    if (cout != null) 'cout': cout,
    if (notes != null) 'notes': notes,
  };
}
