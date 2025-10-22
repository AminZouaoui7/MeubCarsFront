// lib/Data/Api/visites_techniques_api.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:meubcars/core/cache/CacheHelper.dart';
import 'package:meubcars/core/api/endpoints.dart';

class VisiteTechniqueDto {
  int? id;
  int voitureId;
  String? libelle;
  String? centre;
  String? numeroRapport;
  bool contreVisite;
  DateTime? dateDebut;
  DateTime? dateFin;
  DateTime? datePaiement;
  DateTime? dateProchainPaiement;
  double? montant;
  String? fichierUrl;
  String? notes;

  VisiteTechniqueDto({
    this.id,
    required this.voitureId,
    this.libelle,
    this.centre,
    this.numeroRapport,
    this.contreVisite = false,
    this.dateDebut,
    this.dateFin,
    this.datePaiement,
    this.dateProchainPaiement,
    this.montant,
    this.fichierUrl,
    this.notes,
  });

  factory VisiteTechniqueDto.fromJson(Map<String, dynamic> j) {
    DateTime? _d(v) =>
        (v == null || v.toString().isEmpty) ? null : DateTime.tryParse(v.toString());
    double? _toDouble(v) =>
        (v == null) ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

    return VisiteTechniqueDto(
      id: (j['id'] ?? j['Id']) as int?,
      voitureId: (j['voitureId'] ?? j['VoitureId']) as int,
      libelle: (j['libelle'] ?? j['Libelle'])?.toString(),
      centre: (j['centre'] ?? j['Centre'])?.toString(),
      numeroRapport: (j['numeroRapport'] ?? j['NumeroRapport'])?.toString(),
      contreVisite: (j['contreVisite'] ?? j['ContreVisite'] ?? false) == true,
      dateDebut: _d(j['dateDebut'] ?? j['DateDebut']),
      dateFin: _d(j['dateFin'] ?? j['DateFin']),
      datePaiement: _d(j['datePaiement'] ?? j['DatePaiement']),
      dateProchainPaiement: _d(j['dateProchainPaiement'] ?? j['DateProchainPaiement']),
      montant: _toDouble(j['montant'] ?? j['Montant']),
      fichierUrl: (j['fichierUrl'] ?? j['FichierUrl'])?.toString(),
      notes: (j['notes'] ?? j['Notes'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'voitureId': voitureId,
    'libelle': libelle,
    'centre': centre,
    'numeroRapport': numeroRapport,
    'contreVisite': contreVisite,
    'dateDebut': dateDebut?.toIso8601String(),
    'dateFin': dateFin?.toIso8601String(),
    'datePaiement': datePaiement?.toIso8601String(),
    'dateProchainPaiement': dateProchainPaiement?.toIso8601String(),
    'montant': montant,
    'fichierUrl': fichierUrl,
    'notes': notes,
  };
}

class VisitesTechniquesApi {
  final Dio _dio;

  VisitesTechniquesApi._(this._dio);

  static Future<VisitesTechniquesApi> authed() async {
    final base = EndPoint.baseUrl; // ex: http://10.0.2.2:7178/api/
    final dio = Dio(BaseOptions(
      baseUrl: base.endsWith('/') ? base : '$base/',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));
    final token = await CacheHelper.getData(key: 'token');
    if (token != null && token.toString().isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
    dio.options.headers['Accept'] = 'application/json';
    return VisitesTechniquesApi._(dio);
  }

  Future<List<VisiteTechniqueDto>> list({int? voitureId}) async {
    final res = await _dio.get('VisitesTechniques',
        queryParameters: voitureId == null ? null : {'voitureId': voitureId});
    final data = (res.data as List?) ?? const [];
    return data.map((e) => VisiteTechniqueDto.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<VisiteTechniqueDto> getOne(int id) async {
    final res = await _dio.get('VisitesTechniques/$id');
    return VisiteTechniqueDto.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<VisiteTechniqueDto> create(VisiteTechniqueDto dto) async {
    final res = await _dio.post('VisitesTechniques', data: dto.toJson());
    return VisiteTechniqueDto.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<void> update(VisiteTechniqueDto dto) async {
    if (dto.id == null) throw Exception('Visite ID manquant');
    await _dio.put('VisitesTechniques/${dto.id}', data: dto.toJson());
  }

  Future<void> delete(int id) async {
    await _dio.delete('VisitesTechniques/$id');
  }

  Future<void> payer({
    required int id,
    required DateTime datePaiement,
    int nextInYears = 1,
    String? fichierUrl,
  }) async {
    await _dio.put('VisitesTechniques/$id/payer', data: {
      'datePaiement': datePaiement.toIso8601String(),
      'nextInYears': nextInYears,
      'fichierUrl': fichierUrl,
    });
  }
}
