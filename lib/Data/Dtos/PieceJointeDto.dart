// piece_jointe_dto.dart
DateTime? _dt(dynamic v) => v == null ? null : DateTime.parse(v as String);
T? _opt<T>(Map m, String k) => m[k] as T?;
class PieceJointeDto {
  final int id;
  final int voitureId;
  final String fichierUrl;
  final String? titre;
  final String? typeMime;
  final DateTime uploadAt;

  PieceJointeDto({
    required this.id,
    required this.voitureId,
    required this.fichierUrl,
    this.titre,
    this.typeMime,
    required this.uploadAt,
  });

  factory PieceJointeDto.fromJson(Map<String, dynamic> j) => PieceJointeDto(
    id: j['id'] as int,
    voitureId: j['voitureId'] as int,
    fichierUrl: j['fichierUrl'] as String,
    titre: j['titre'] as String?,
    typeMime: j['typeMime'] as String?,
    uploadAt: _dt(j['uploadAt']) ?? DateTime.now(),
  );
}
