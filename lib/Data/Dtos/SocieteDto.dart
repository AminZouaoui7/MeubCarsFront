class SocieteDto {
  final int id;
  final String nom;
  final String? code;
  final String? adresse;
  final String? telephone;

  SocieteDto({
    required this.id,
    required this.nom,
    this.code,
    this.adresse,
    this.telephone,
  });

  factory SocieteDto.fromJson(Map<String, dynamic> j) => SocieteDto(
    id: j['id'] as int,
    nom: j['nom'] as String,
    code: j['code'] as String?,
    adresse: j['adresse'] as String?,
    telephone: j['telephone'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    if (code != null) 'code': code,
    if (adresse != null) 'adresse': adresse,
    if (telephone != null) 'telephone': telephone,
  };
}
