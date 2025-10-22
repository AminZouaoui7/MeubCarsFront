// lib/Data/Dtos/PaiementApi.dart
import 'dart:convert';
import 'dart:io' show File, HttpHeaders; // Safe on mobile/desktop
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import 'package:meubcars/core/cache/CacheHelper.dart';
import 'package:meubcars/core/api/endpoints.dart';

/// ===============================================================
/// PARAMÈTRES DE MAPPING ENUM BACKEND
/// ===============================================================
const int kBackendEnumTaxe = 5;
const int kBackendEnumAutre = 6;
const bool kLogRawPaymentType = false;

/// ============================ TYPES ============================
enum PaymentType {
  Assurance,
  CarteGrise,
  Vignette,
  VisiteTechnique,
  Entretien,
  Taxe,
  Autre,
}

PaymentType paymentTypeFromAny(dynamic raw, {String? sourceTable}) {
  if (raw is num) {
    final v = raw.toInt();
    switch (v) {
      case 0:
        return PaymentType.Assurance;
      case 1:
        return PaymentType.CarteGrise;
      case 2:
        return PaymentType.Vignette;
      case 3:
        return PaymentType.VisiteTechnique;
      case 4:
        return PaymentType.Entretien;
      case kBackendEnumTaxe:
        return PaymentType.Taxe;
      case kBackendEnumAutre:
        return PaymentType.Autre;
      default:
        final st = (sourceTable ?? '').toLowerCase();
        if (st.contains('tax')) return PaymentType.Taxe;
        return PaymentType.Autre;
    }
  }

  if (raw != null) {
    final k = raw.toString().replaceAll(RegExp(r'[\s_\-]'), '').toLowerCase();
    switch (k) {
      case 'assurance':
        return PaymentType.Assurance;
      case 'cartegrise':
        return PaymentType.CarteGrise;
      case 'vignette':
        return PaymentType.Vignette;
      case 'visitetechnique':
      case 'visitetech':
      case 'controletechnique':
      case 'contrôletechnique':
        return PaymentType.VisiteTechnique;
      case 'entretien':
        return PaymentType.Entretien;
      case 'taxe':
      case 'taxes':
      case 'tax':
        return PaymentType.Taxe;
      case 'autre':
      case 'other':
        return PaymentType.Autre;
    }
  }

  final st = (sourceTable ?? '').toLowerCase();
  if (st.contains('assurance')) return PaymentType.Assurance;
  if (st.contains('cartegrise')) return PaymentType.CarteGrise;
  if (st.contains('vignette')) return PaymentType.Vignette;
  if (st.contains('visite')) return PaymentType.VisiteTechnique;
  if (st.contains('entretien')) return PaymentType.Entretien;
  if (st.contains('tax')) return PaymentType.Taxe;
  return PaymentType.Autre;
}

String paymentTypeToString(PaymentType t) {
  switch (t) {
    case PaymentType.Assurance:
      return 'Assurance';
    case PaymentType.CarteGrise:
      return 'CarteGrise';
    case PaymentType.Vignette:
      return 'Vignette';
    case PaymentType.VisiteTechnique:
      return 'VisiteTechnique';
    case PaymentType.Entretien:
      return 'Entretien';
    case PaymentType.Taxe:
      return 'Taxe';
    case PaymentType.Autre:
      return 'Autre';
  }
}

String paymentTypeToLabel(PaymentType t, {int? subType}) {
  switch (t) {
    case PaymentType.Assurance:
      return 'Assurance';
    case PaymentType.CarteGrise:
      return 'Carte grise';
    case PaymentType.Vignette:
      return 'Vignette';
    case PaymentType.VisiteTechnique:
      return 'Visite technique';
    case PaymentType.Entretien:
      if (subType == 1) return 'Entretien — Vidange';
      if (subType == 2) return 'Entretien — Panne';
      return 'Entretien';
    case PaymentType.Taxe:
      return 'Taxe';
    case PaymentType.Autre:
      return 'Paiement';
  }
}

/// ============================ MODELS ============================
class PaymentItem {
  final PaymentType type;
  final int id;
  final int voitureId;
  final String? libelle;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final DateTime? datePaiement;
  final DateTime? dateProchainPaiement;
  final double? montant;
  final String? fichierUrl;
  final String? notes;
  final bool isOverdue;
  final bool isDueSoon;
  final bool isDueThisMonth;
  final bool estActive;

  PaymentItem({
    required this.type,
    required this.id,
    required this.voitureId,
    this.libelle,
    this.dateDebut,
    this.dateFin,
    this.datePaiement,
    this.dateProchainPaiement,
    this.montant,
    this.fichierUrl,
    this.notes,
    required this.isOverdue,
    required this.isDueSoon,
    required this.isDueThisMonth,
    required this.estActive,
  });

  DateTime? get dueDate => dateProchainPaiement ?? dateFin ?? dateDebut;

  factory PaymentItem.fromJson(Map<String, dynamic> j) {
    DateTime? _parse(dynamic s) =>
        (s == null) ? null : DateTime.tryParse(s.toString());
    double? _numToDouble(dynamic n) {
      if (n == null) return null;
      if (n is num) return n.toDouble();
      return double.tryParse(n.toString());
    }

    final sourceTable = j['sourceTable'] as String?;

    return PaymentItem(
      type: paymentTypeFromAny(j['type'], sourceTable: sourceTable),
      id: j['id'] as int,
      voitureId: j['voitureId'] as int,
      libelle: j['libelle'] as String?,
      dateDebut: _parse(j['dateDebut']),
      dateFin: _parse(j['dateFin']),
      datePaiement: _parse(j['datePaiement']),
      dateProchainPaiement: _parse(j['dateProchainPaiement']),
      montant: _numToDouble(j['montant']),
      fichierUrl: j['fichierUrl'] as String?,
      notes: j['notes'] as String?,
      isOverdue: j['isOverdue'] as bool? ?? false,
      isDueSoon: j['isDueSoon'] as bool? ?? false,
      isDueThisMonth: j['isDueThisMonth'] as bool? ?? false,
      estActive: j['estActive'] as bool? ?? true,
    );
  }
}

class PaymentSummary {
  final int totalDue;
  final int dueSoon;
  final int overdue;
  final int paidThisMonth;
  final List<PaymentItem> items;

  PaymentSummary({
    required this.totalDue,
    required this.dueSoon,
    required this.overdue,
    required this.paidThisMonth,
    required this.items,
  });

  int get badgeCount => overdue + dueSoon;

  factory PaymentSummary.fromJson(Map<String, dynamic> j) {
    final itemsJson = (j['items'] as List<dynamic>? ?? []);
    final allItems = itemsJson
        .map((e) => PaymentItem.fromJson(e as Map<String, dynamic>))
        .where((it) => it.estActive)
        .toList();

    return PaymentSummary(
      totalDue: j['totalDue'] as int? ?? 0,
      dueSoon: j['dueSoon'] as int? ?? 0,
      overdue: j['overdue'] as int? ?? 0,
      paidThisMonth: j['paidThisMonth'] as int? ?? 0,
      items: allItems,
    );
  }
}

class PaiementVM {
  final int id, voitureId;
  final PaymentType type;
  final int? subType, sourceId;
  final String? sourceTable, notes;
  final double montant;
  final DateTime datePaiement;
  final DateTime? dateProchainPaiement, createdAt;

  PaiementVM.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        voitureId = j['voitureId'],
        type = paymentTypeFromAny(j['type'], sourceTable: j['sourceTable'] as String?),
        subType = j['subType'],
        sourceId = j['sourceId'],
        sourceTable = j['sourceTable'],
        notes = j['notes'],
        montant = (j['montant'] as num).toDouble(),
        datePaiement = DateTime.parse(j['datePaiement'].toString()),
        dateProchainPaiement = j['dateProchainPaiement'] == null
            ? null
            : DateTime.parse(j['dateProchainPaiement'].toString()),
        createdAt = j['createdAt'] == null
            ? null
            : DateTime.parse(j['createdAt'].toString());
}

/// ============================ API ============================
class PaiementsApi {
  final Dio _dio;
  PaiementsApi(this._dio);

  static Future<PaiementsApi> authed() async {
    final token = await CacheHelper.getData(key: 'token');
    final dio = Dio(
      BaseOptions(
        baseUrl: EndPoint.baseUrl,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          if (token != null && token.toString().isNotEmpty)
            HttpHeaders.authorizationHeader: 'Bearer $token',
        },
      ),
    );
    print("✅ PaiementsApi initialized with baseUrl=${EndPoint.baseUrl}");
    return PaiementsApi(dio);
  }

  /// Historique avec filtres
  Future<List<PaiementVM>> history({
    int? voitureId,
    PaymentType? type,
    int? subType,
    int? sourceId,
    String? sourceTable,
    DateTime? from,
    DateTime? to,
  }) async {
    final q = <String, dynamic>{};
    if (voitureId != null) q['voitureId'] = voitureId;
    if (type != null && type != PaymentType.Autre) {
      q['type'] = paymentTypeToString(type);
    }
    if (subType != null) q['subType'] = subType;
    if (sourceId != null) q['sourceId'] = sourceId;
    if (sourceTable != null && sourceTable.isNotEmpty) q['sourceTable'] = sourceTable;
    if (from != null) q['from'] = from.toIso8601String();
    if (to != null) q['to'] = to.toIso8601String();

    final res = await _dio.get('/paiements/history', queryParameters: q);
    final list = res.data as List<dynamic>;
    return list.map((e) => PaiementVM.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Résumé mensuel
  Future<PaymentSummary> fetchSummary({
    DateTime? month,
    int? voitureId,
    int dueDays = 7,
  }) async {
    final params = <String, dynamic>{
      if (month != null) 'month': DateTime(month.year, month.month, 1).toIso8601String(),
      if (voitureId != null) 'voitureId': voitureId,
      'dueDays': dueDays,
    };

    final res = await _dio.get('/paiements/summary', queryParameters: params);
    return PaymentSummary.fromJson(res.data as Map<String, dynamic>);
  }

  /// Upload justificatif avec File (mobile/desktop)
  Future<String?> uploadJustificatif({
    required File file,
    required int voitureId,
  }) async {
    final fileName = file.path.split('/').last;

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });

    final endpoint = '/voitures/$voitureId/pieces-jointes/upload';
    final res = await _dio.post(
      endpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    print("📤 Upload status=${res.statusCode}, data=${res.data}");
    return _extractFileUrl(res);
  }

  /// Upload justificatif avec Bytes (web)
  Future<String?> uploadJustificatifWithBytes({
    required Uint8List bytes,
    required String filename,
    required int voitureId,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final endpoint = '/voitures/$voitureId/pieces-jointes/upload';
    final res = await _dio.post(
      endpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    print("📤 Upload status=${res.statusCode}, data=${res.data}");
    return _extractFileUrl(res);
  }

  String? _extractFileUrl(Response res) {
    if (res.statusCode == 200 || res.statusCode == 201) {
      if (res.data is Map) {
        final map = res.data as Map<String, dynamic>;
        return map['url'] ?? map['fichierUrl'];
      }
    }
    return null;
  }

  /// FilePicker cross-plateforme
  static Future<PlatformFile?> pickOneFile({List<String>? allowedExt}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: allowedExt == null ? FileType.any : FileType.custom,
      allowedExtensions: allowedExt,
    );
    return result?.files.single;
  }
}

/// ============================ /{id}/payer ============================
extension PaiementsPayer on PaiementsApi {
  String _payerPathFor(PaymentType t) {
    switch (t) {
      case PaymentType.Assurance:
        return '/Assurances';
      case PaymentType.CarteGrise:
        return '/CartesGrises';
      case PaymentType.Vignette:
        return '/Vignettes';
      case PaymentType.VisiteTechnique:
        return '/VisitesTechniques';
      case PaymentType.Entretien:
        return '/Entretiens';
      case PaymentType.Taxe:
        return '/Taxes';
      case PaymentType.Autre:
        return '/Autres';
    }
  }

  Future<void> payerDocument({
    required PaymentType type,
    required int id,
    required DateTime datePaiement,
    DateTime? dateProchainPaiement,
    String? notes,
    num? montant,
    String? fichierUrl,
  }) async {
    final endpoint = "${_payerPathFor(type)}/$id/payer";
    final body = {
      "type": paymentTypeToString(type),
      "datePaiement": datePaiement.toIso8601String(),
      "dateProchainPaiement": dateProchainPaiement?.toIso8601String(),
      "notes": notes,
      "montant": montant,
      "fichierUrl": fichierUrl,
    };

    final resp = await _dio.post(endpoint, data: body);
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception("Erreur paiement: ${resp.data}");
    }
  }
}

/// ============================ markAsPaidWithUpload ============================
extension PaiementsExtras on PaiementsApi {
  Future<void> markAsPaidWithUpload({
    required PaymentType type,
    required int id,
    required int voitureId,
    required DateTime dateDebut,
    required DateTime dateFin,
    required DateTime datePaiement,
    required DateTime dateProchainPaiement,
    String? notes,
    num? montant,
    PlatformFile? pickedFile,
  }) async {
    String? fichierUrl;

    // Upload fichier
    if (pickedFile != null) {
      if (pickedFile.bytes != null) {
        fichierUrl = await uploadJustificatifWithBytes(
          bytes: pickedFile.bytes!,
          filename: pickedFile.name,
          voitureId: voitureId,
        );
      } else if (pickedFile.path != null) {
        final f = File(pickedFile.path!);
        fichierUrl = await uploadJustificatif(file: f, voitureId: voitureId);
      }
    }

    final body = {
      "Type": paymentTypeToString(type),
      "DateDebut": dateDebut.toIso8601String(),
      "DateFin": dateFin.toIso8601String(),
      "DatePaiement": datePaiement.toIso8601String(),
      "DateProchainPaiement": dateProchainPaiement.toIso8601String(),
      "Notes": notes,
      "Montant": montant,
      "FichierUrl": fichierUrl,
    };

    final endpoint = "${_payerPathFor(type)}/$id/payer";
    final resp = await _dio.post(endpoint, data: body);

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception("Erreur paiement: ${resp.data}");
    }
  }
}
