// voiture_dto.dart
import 'package:meubcars/Data/Dtos/AssuranceDto.dart';
import 'package:meubcars/Data/Dtos/CarteGriseDto.dart';
import 'package:meubcars/Data/Dtos/SocieteDto.dart';
import 'package:meubcars/Data/Dtos/VignetteDto.dart';



class VoitureDto {
  final int id;
  final String matricule;
  final String? matriculeNormalized;
  final int? societeId;
  final SocieteDto?  societeRef;
  final String? marque;
  final String? modele;
  final int? annee;
  final String? numeroChassis;
  final String? carburant; // (Enum côté C# -> string côté DTO)
  final int? kilometrage;
  final DateTime? dateAchat;
  final double? prixAchat;
  final bool active;
  final List<AssuranceDto> assurances;
  final List<CarteGriseDto> cartesGrises;
  final List<VignetteDto> vignettes;

  VoitureDto({
    required this.id,
    required this.matricule,
    this.matriculeNormalized,
    this.societeId,
    required this.societeRef,
    this.marque,
    this.modele,
    this.annee,
    this.numeroChassis,
    this.carburant,
    this.kilometrage,
    this.dateAchat,
    this.prixAchat,
    required this.active,
    required this.assurances,
    required this.cartesGrises,
    required this.vignettes,
  });

  factory VoitureDto.fromJson(Map<String, dynamic> j) => VoitureDto(
    id: j['id'] as int,
    matricule: j['matricule'] as String,
    matriculeNormalized: j['matriculeNormalized'] as String?,
    societeId: j['societeId'] as int?,
    societeRef: j['societeRef'] == null ? null : SocieteDto.fromJson(j['societeRef']),
    marque: j['marque'] as String?,
    modele: j['modele'] as String?,
    annee: j['annee'] as int?,
    numeroChassis: j['numeroChassis'] as String?,
    carburant: j['carburant']?.toString(),
    kilometrage: j['kilometrage'] as int?,
    dateAchat: j['dateAchat'] == null ? null : DateTime.parse(j['dateAchat']),
    prixAchat: j['prixAchat'] == null ? null : (j['prixAchat'] as num).toDouble(),
    active: (j['active'] as bool?) ?? true,
    assurances: (j['assurances'] as List? ?? [])
        .map((e) => AssuranceDto.fromJson(e))
        .toList(),
    cartesGrises: (j['cartesGrises'] as List? ?? [])
        .map((e) => CarteGriseDto.fromJson(e))
        .toList(),
    vignettes: (j['vignettes'] as List? ?? [])
        .map((e) => VignetteDto.fromJson(e))
        .toList(),
  );
}

