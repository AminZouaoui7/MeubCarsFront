// lib/Views/Voiture/VoitureEditPage.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';

import 'package:meubcars/core/cache/CacheHelper.dart';
import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/background.dart';

/// Option d'une société pour la liste déroulante
class SocieteOption {
  final int id;
  final String nom;
  const SocieteOption({required this.id, required this.nom});
}

class VoitureEditPage extends StatefulWidget {
  const VoitureEditPage({super.key});
  @override
  State<VoitureEditPage> createState() => _VoitureEditPageState();
}

class _VoitureEditPageState extends State<VoitureEditPage> {
  // ====== HTTP ======
  final Dio _dio = Dio(BaseOptions(baseUrl: EndPoint.baseUrl));

  Future<Map<String, String>> _authHeaders() async {
    final token = await CacheHelper.getData(key: 'token');
    final h = <String, String>{'Accept': 'application/json'};
    if (token != null && token
        .toString()
        .isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Future<Response> _postJson(String path, Map<String, dynamic> data) async {
    final headers = await _authHeaders();
    return _dio.post(path,
        data: data,
        options:
        Options(headers: {...headers, 'Content-Type': 'application/json'}));
  }

  Future<Response> _putJson(String path, Map<String, dynamic> data) async {
    final headers = await _authHeaders();
    return _dio.put(path,
        data: data,
        options:
        Options(headers: {...headers, 'Content-Type': 'application/json'}));
  }

  // ====== URL helpers ======
  String _apiOrigin() {
    var b = EndPoint.baseUrl;
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    if (b.toLowerCase().endsWith('/api')) b = b.substring(0, b.length - 4);
    Uri u;
    try {
      u = Uri.parse(b);
    } catch (_) {
      return b;
    }
    String scheme = u.scheme.isEmpty ? 'http' : u.scheme;
    String host = u.host.isEmpty ? 'localhost' : u.host;
    int port = u.hasPort ? u.port : (scheme == 'https' ? 443 : 80);
    if (!kIsWeb && Platform.isAndroid) {
      if (host == 'localhost' || host == '127.0.0.1') host = '10.0.2.2';
      if (scheme == 'https') scheme = 'http';
    }
    final p = (port == 80 && scheme == 'http') ||
        (port == 443 && scheme == 'https')
        ? '' : ':$port';
    return '$scheme://$host$p';
  }

  String _encodeSegments(String path) {
    final leadingSlash = path.startsWith('/');
    final parts = path.split('/');
    final encoded = <String>[];
    for (final seg in parts) {
      if (seg.isEmpty) {
        encoded.add('');
        continue;
      }
      final de = Uri.decodeComponent(seg);
      encoded.add(Uri.encodeComponent(de));
    }
    final joined = encoded.join('/');
    return leadingSlash && !joined.startsWith('/') ? '/$joined' : joined;
  }

  String _absoluteFrom(String urlOrPath) {
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      final u = Uri.parse(urlOrPath);
      var scheme = u.scheme;
      var host = u.host;
      final port = u.hasPort ? u.port : null;
      if (!kIsWeb && Platform.isAndroid &&
          (host == 'localhost' || host == '127.0.0.1')) {
        host = '10.0.2.2';
        if (scheme == 'https') scheme = 'http';
      }
      return Uri(scheme: scheme,
          host: host,
          port: port,
          path: _encodeSegments(u.path),
          query: u.hasQuery ? u.query : null).toString();
    }
    final origin = _apiOrigin();
    String p = urlOrPath.isEmpty ? urlOrPath :
    (urlOrPath.startsWith('/') ? urlOrPath : '/$urlOrPath');
    p = p.replaceAll(RegExp(r'/{2,}'), '/');
    return '$origin${_encodeSegments(p)}';
  }

  // ====== Stepper / State ======
  int _currentStep = 0;
  bool _busy = false;

  // IDs
  int? _voitureId;
  int? _assuranceId;
  int? _cgId;
  int? _vignetteId;
  int? _taxeId; // ✅ AJOUT taxe
  // ====== Forms keys ======
  final _formVoiture = GlobalKey<FormState>();
  final _formAssurance = GlobalKey<FormState>();
  final _formCarteGrise = GlobalKey<FormState>();
  final _formVignette = GlobalKey<FormState>();
  final _formTaxe = GlobalKey<FormState>(); // ✅ AJOUT taxe

  final _numInterneCtrl = TextEditingController();
  bool _saisieEffectuee = false;
  String? _occupee = 'Libre';


  // ====== Taxe ======
  final _taxeTypeCtrl = TextEditingController();
  final _taxeMontantCtrl = TextEditingController();
  DateTime? _taxeDateDebut;
  DateTime? _taxeDateFin;
  DateTime? _taxeDatePaiement;
  DateTime? _taxeDateProchainPaiement;
  String? _taxeFichierUrl;
  String? _taxePreviewUrl;
  final _taxeNotesCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _matriculeCtrl,
      _marqueCtrl,
      _modeleCtrl,
      _anneeCtrl,
      _numeroChassisCtrl,
      _kilometrageCtrl,
      _prixAchatCtrl,
      _numInterneCtrl, // ✅ nouveau champ
      _assuranceCompagnieCtrl,
      _assuranceNumeroPoliceCtrl,
      _assuranceMontantCtrl,
      _assuranceNotesCtrl,
      _cgNumeroCarteCtrl,
      _cgProprietaireCtrl,
      _cgMontantCtrl,
      _cgNotesCtrl,
      _vAnneeFiscaleCtrl,
      _vNumeroQuitanceCtrl,
      _vMontantCtrl,
      _vNotesCtrl,
      _taxeTypeCtrl,
      _taxeMontantCtrl,
      _taxeNotesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ====== Upload helper ======
  Future<({String rawUrl, String previewUrl})?> _uploadFile(
      {required String category}) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false, withData: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (picked == null || picked.files.isEmpty) return null;
      final f = picked.files.single;
      MultipartFile filePart;
      final ext = (f.extension ?? '').toLowerCase();
      final mime = ext == 'pdf' ? 'application/pdf'
          : (ext == 'jpg' || ext == 'jpeg') ? 'image/jpeg' : 'image/png';
      if (f.bytes != null) {
        filePart = MultipartFile.fromBytes(
            f.bytes!, filename: f.name, contentType: MediaType.parse(mime));
      } else if (f.path != null) {
        filePart = await MultipartFile.fromFile(
            f.path!, filename: f.name, contentType: MediaType.parse(mime));
      } else {
        _toast('Impossible de lire le fichier');
        return null;
      }
      final form = FormData.fromMap({'file': filePart, 'category': category});
      final headers = await _authHeaders();
      final res = await _dio.post(
          'Uploads', data: form, options: Options(headers: headers));
      final data = res.data is Map ? (res.data as Map) : {};
      final raw = (data['url'] ?? data['path'] ?? data['fileUrl'] ?? '')
          .toString();
      if (raw.isEmpty) {
        _toast('Réponse upload invalide');
        return null;
      }
      final abs = _absoluteFrom(raw);
      _toast('Fichier téléversé ✔');
      return (rawUrl: raw, previewUrl: abs);
    } on DioException catch (e) {
      _toast(e.response?.data?.toString() ?? e.message ?? 'Upload échoué');
      return null;
    } catch (e) {
      _toast(e.toString());
      return null;
    }
  }

  String _uploadsFallback(String absUrl) {
    final needle = '://';
    final i = absUrl.indexOf(needle);
    if (i < 0) return absUrl;
    final hostPartEnd = absUrl.indexOf('/', i + needle.length);
    if (hostPartEnd < 0) return absUrl;
    final host = absUrl.substring(0, hostPartEnd);
    final path = absUrl.substring(hostPartEnd);
    if (RegExp(r'^/uploads/(?!uploads/)', caseSensitive: false).hasMatch(
        path)) {
      return '$host' + path.replaceFirst(
          RegExp(r'^/uploads/', caseSensitive: false), '/uploads/uploads/');
    }
    return absUrl;
  }

  bool _looksLikeImage(String? url) {
    final s = (url ?? '').toLowerCase();
    return s.endsWith('.png') || s.endsWith('.jpg') || s.endsWith('.jpeg') ||
        s.contains('.png?') || s.contains('.jpg?') || s.contains('.jpeg?');
  }

  DateTime? _tryParseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  // ====== Sociétés ======
  List<SocieteOption> _societes = <SocieteOption>[];
  int? _selectedSocieteId;
  bool _loadingSocietes = false;

  // ====== Voiture ======
  final _matriculeCtrl = TextEditingController();
  final _marqueCtrl = TextEditingController();
  final _modeleCtrl = TextEditingController();
  final _anneeCtrl = TextEditingController();
  final _numeroChassisCtrl = TextEditingController();
  final _kilometrageCtrl = TextEditingController();
  final _prixAchatCtrl = TextEditingController();
  DateTime? _dateAchat;
  String? _carburant;
  bool _active = true;

  // ====== Assurance ======
  final _assuranceCompagnieCtrl = TextEditingController();
  final _assuranceNumeroPoliceCtrl = TextEditingController();
  final _assuranceMontantCtrl = TextEditingController();
  DateTime? _assuranceDebut;
  DateTime? _assuranceFin;
  DateTime? _assuranceDatePaiement;
  DateTime? _assuranceDateProchainPaiement;
  bool _assuranceTousRisques = false;
  final _assuranceNotesCtrl = TextEditingController();
  String? _assuranceFichierUrl;
  String? _assurancePreviewUrl;

  // ====== Carte grise ======
  final _cgNumeroCarteCtrl = TextEditingController();
  final _cgProprietaireCtrl = TextEditingController();
  final _cgMontantCtrl = TextEditingController();
  DateTime? _cgDateDebut;
  DateTime? _cgDateFin;
  DateTime? _cgDatePaiement;
  DateTime? _cgDateProchainPaiement;
  String? _cgFichierUrl;
  String? _cgPreviewUrl;
  final _cgNotesCtrl = TextEditingController();

  // ====== Vignette ======
  final _vAnneeFiscaleCtrl = TextEditingController();
  final _vNumeroQuitanceCtrl = TextEditingController();
  final _vMontantCtrl = TextEditingController();
  DateTime? _vDateDebut;
  DateTime? _vDateFin;
  DateTime? _vDatePaiement;
  DateTime? _vDateProchainPaiement;
  String? _vFichierUrl;
  String? _vPreviewUrl;
  final _vNotesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSocietes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_voitureId == null) {
      _voitureId = ModalRoute
          .of(context)
          ?.settings
          .arguments as int?;
      if (_voitureId != null) _loadVoiture(_voitureId!);
    }
  }

  Future<void> _fetchSocietes() async {
    try {
      setState(() => _loadingSocietes = true);
      final headers = await _authHeaders();
      final res = await _dio.get(
          'Societes', options: Options(headers: headers));

      final raw = res.data;
      final List<dynamic> list = raw is List ? raw : <dynamic>[];
      final parsed = list.map<SocieteOption>((dynamic item) {
        final m = (item as Map).map<String, dynamic>((k, v) =>
            MapEntry(k.toString(), v));
        final id = (m['id'] ?? m['Id']) as int? ??
            (m['id'] as num?)?.toInt() ?? (m['Id'] as num?)?.toInt() ?? 0;
        final nomRaw = m['nom'] ?? m['Nom'] ?? m['name'] ?? m['Name'] ?? '';
        final nom = nomRaw?.toString() ?? '';
        return SocieteOption(id: id, nom: nom.isEmpty ? 'Société #$id' : nom);
      }).where((s) => s.id != 0).toList();

      setState(() => _societes = parsed);
    } catch (_) {
      _toast('Impossible de charger les sociétés');
    } finally {
      if (mounted) setState(() => _loadingSocietes = false);
    }
  }

  Future<void> _loadVoiture(int id) async {
    try {
      setState(() => _busy = true);
      final headers = await _authHeaders();
      final res = await _dio.get('Voitures/$id', options: Options(headers: headers));
      if (res.statusCode != 200) throw Exception('Erreur serveur (${res.statusCode})');

      final m = (res.data as Map).cast<String, dynamic>();

      // --- Voiture
      _matriculeCtrl.text = (m['matricule'] ?? '').toString();
      _marqueCtrl.text = (m['marque'] ?? '').toString();
      _modeleCtrl.text = (m['modele'] ?? '').toString();
      _anneeCtrl.text = (m['annee'] ?? '').toString();
      _numeroChassisCtrl.text = (m['numeroChassis'] ?? '').toString();
      _kilometrageCtrl.text = (m['kilometrage'] ?? '').toString();
      _prixAchatCtrl.text = (m['prixAchat'] ?? '').toString();

      // ✅ Carburant: compatible avec int ou String
      final carbVal = m['carburant'];
      if (carbVal == null) {
        _carburant = null;
      } else {
        final val = carbVal is int ? carbVal : int.tryParse(carbVal.toString());
        switch (val) {
          case 0:
            _carburant = 'Essence';
            break;
          case 1:
            _carburant = 'Diesel';
            break;
          case 2:
            _carburant = 'Hybride';
            break;
          case 3:
            _carburant = 'Electrique';
            break;
          default:
            final s = carbVal.toString().toLowerCase();
            if (s.contains('essence')) {
              _carburant = 'Essence';
            } else if (s.contains('diesel')) {
              _carburant = 'Diesel';
            } else if (s.contains('hybride')) {
              _carburant = 'Hybride';
            } else if (s.contains('elect') || s.contains('élect')) {
              _carburant = 'Electrique';
            } else {
              _carburant = null;
            }
        }
      }

      _dateAchat = _tryParseDate(m['dateAchat']);
      _active = (m['active'] == true || m['active'] == 1);

      // ✅ Champs supplémentaires
      _numInterneCtrl.text = (m['numInterne'] ?? '').toString();
      _saisieEffectuee = (m['saisie'] == true || m['saisie'] == 1);
      final occ = (m['occupee'] ?? '').toString().trim();
      _occupee = occ.isEmpty ? 'Libre' : occ;

      // --- Société
      int? sid;
      if (m['societeId'] != null) {
        sid = (m['societeId'] is num)
            ? (m['societeId'] as num).toInt()
            : int.tryParse(m['societeId'].toString());
      } else if (m['societeRef'] is Map) {
        final sm = (m['societeRef'] as Map).cast<String, dynamic>();
        sid = (sm['id'] is num)
            ? (sm['id'] as num).toInt()
            : int.tryParse((sm['id'] ?? '').toString());
      }
      _selectedSocieteId = sid;

      // Helpers
      List<Map<String, dynamic>> _toList(dynamic v) =>
          ((v as List?) ?? const [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();

      Map<String, dynamic>? _latestByDate(List<Map<String, dynamic>> list, String dateKey) {
        if (list.isEmpty) return null;
        list.sort((a, b) {
          final ad = _tryParseDate(a[dateKey]) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = _tryParseDate(b[dateKey]) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
        return list.first;
      }

      // --- Assurance
      final assurances = _toList(m['assurances']);
      final a = _latestByDate(assurances, 'dateDebut');
      if (a != null) {
        _assuranceId = (a['id'] is num) ? (a['id'] as num).toInt() : int.tryParse('${a['id']}');
        _assuranceCompagnieCtrl.text = (a['compagnie'] ?? '').toString();
        _assuranceNumeroPoliceCtrl.text = (a['numeroPolice'] ?? '').toString();
        _assuranceTousRisques = a['tousRisques'] == true;
        _assuranceMontantCtrl.text = (a['montant'] ?? '').toString();
        _assuranceDebut = _tryParseDate(a['dateDebut']);
        _assuranceFin = _tryParseDate(a['dateFin']);
        _assuranceDatePaiement = _tryParseDate(a['datePaiement']);
        _assuranceDateProchainPaiement = _tryParseDate(a['dateProchainPaiement']);
        _assuranceFichierUrl = (a['fichierUrl'] ?? '').toString().isEmpty ? null : a['fichierUrl'].toString();
        _assurancePreviewUrl = _assuranceFichierUrl == null ? null : _absoluteFrom(_assuranceFichierUrl!);
        _assuranceNotesCtrl.text = (a['notes'] ?? '').toString();
      }

      // --- Carte grise
      final cartes = _toList(m['cartesGrises']);
      final cg = _latestByDate(cartes, 'dateDebut');
      if (cg != null) {
        _cgId = (cg['id'] is num) ? (cg['id'] as num).toInt() : int.tryParse('${cg['id']}');
        _cgNumeroCarteCtrl.text = (cg['numeroCarte'] ?? '').toString();
        _cgProprietaireCtrl.text = (cg['proprietaireLegal'] ?? '').toString();
        _cgMontantCtrl.text = (cg['montant'] ?? '').toString();
        _cgDateDebut = _tryParseDate(cg['dateDebut']);
        _cgDateFin = _tryParseDate(cg['dateFin']);
        _cgDatePaiement = _tryParseDate(cg['datePaiement']);
        _cgDateProchainPaiement = _tryParseDate(cg['dateProchainPaiement']);
        _cgFichierUrl = (cg['fichierUrl'] ?? '').toString().isEmpty ? null : cg['fichierUrl'].toString();
        _cgPreviewUrl = _cgFichierUrl == null ? null : _absoluteFrom(_cgFichierUrl!);
        _cgNotesCtrl.text = (cg['notes'] ?? '').toString();
      }

      // --- Vignette
      final vignettes = _toList(m['vignettes']);
      final vg = _latestByDate(vignettes, 'dateDebut');
      if (vg != null) {
        _vignetteId = (vg['id'] is num) ? (vg['id'] as num).toInt() : int.tryParse('${vg['id']}');
        _vAnneeFiscaleCtrl.text = (vg['anneeFiscale'] ?? '').toString();
        _vNumeroQuitanceCtrl.text = (vg['numeroQuitance'] ?? '').toString();
        _vMontantCtrl.text = (vg['montant'] ?? '').toString();
        _vDateDebut = _tryParseDate(vg['dateDebut']);
        _vDateFin = _tryParseDate(vg['dateFin']);
        _vDatePaiement = _tryParseDate(vg['datePaiement']);
        _vDateProchainPaiement = _tryParseDate(vg['dateProchainPaiement']);
        _vFichierUrl = (vg['fichierUrl'] ?? '').toString().isEmpty ? null : vg['fichierUrl'].toString();
        _vPreviewUrl = _vFichierUrl == null ? null : _absoluteFrom(_vFichierUrl!);
        _vNotesCtrl.text = (vg['notes'] ?? '').toString();
      }

      // --- ✅ Taxes
      final taxes = _toList(m['taxes']);
      final tx = _latestByDate(taxes, 'dateDebut');
      if (tx != null) {
        _taxeId = (tx['id'] is num) ? (tx['id'] as num).toInt() : int.tryParse('${tx['id']}');
        _taxeTypeCtrl.text = (tx['libelle'] ?? '').toString();
        _taxeMontantCtrl.text = (tx['montant'] ?? '').toString();
        _taxeDateDebut = _tryParseDate(tx['dateDebut']);
        _taxeDateFin = _tryParseDate(tx['dateFin']);
        _taxeDatePaiement = _tryParseDate(tx['datePaiement']);
        _taxeDateProchainPaiement = _tryParseDate(tx['dateProchainPaiement']);
        _taxeFichierUrl = (tx['fichierUrl'] ?? '').toString().isEmpty ? null : tx['fichierUrl'].toString();
        _taxePreviewUrl = _taxeFichierUrl == null ? null : _absoluteFrom(_taxeFichierUrl!);
        _taxeNotesCtrl.text = (tx['notes'] ?? '').toString();
      }

      setState(() {});
    } on DioException catch (e) {
      _toast(e.response?.data?.toString() ?? e.message ?? 'Erreur réseau');
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ====== Validations ======
  bool _validateVoitureRequired() {
    final ok = _matriculeCtrl.text
        .trim()
        .isNotEmpty &&
        _selectedSocieteId != null &&
        _marqueCtrl.text
            .trim()
            .isNotEmpty &&
        _modeleCtrl.text
            .trim()
            .isNotEmpty &&
        _anneeCtrl.text
            .trim()
            .isNotEmpty &&
        _numeroChassisCtrl.text
            .trim()
            .isNotEmpty &&
        _kilometrageCtrl.text
            .trim()
            .isNotEmpty &&
        _prixAchatCtrl.text
            .trim()
            .isNotEmpty &&
        _carburant != null &&
        _dateAchat != null;
    if (!ok) _toast('Complète tous les champs de la voiture.');
    return ok;
  }

  bool _validateAssuranceRequired() {
    if (_assuranceId == null &&
        (_assuranceCompagnieCtrl.text
            .trim()
            .isEmpty &&
            _assuranceNumeroPoliceCtrl.text
                .trim()
                .isEmpty &&
            _assuranceMontantCtrl.text
                .trim()
                .isEmpty &&
            _assuranceDebut == null &&
            _assuranceFin == null &&
            _assuranceDatePaiement == null &&
            _assuranceDateProchainPaiement == null &&
            (_assuranceFichierUrl ?? '').isEmpty)) return true;

    final ok = _assuranceCompagnieCtrl.text
        .trim()
        .isNotEmpty &&
        _assuranceNumeroPoliceCtrl.text
            .trim()
            .isNotEmpty &&
        _assuranceMontantCtrl.text
            .trim()
            .isNotEmpty &&
        _assuranceDebut != null &&
        _assuranceFin != null &&
        _assuranceDatePaiement != null &&
        _assuranceDateProchainPaiement != null &&
        (_assuranceFichierUrl ?? '').isNotEmpty;
    if (!ok) _toast(
        'Remplis tous les champs de l’assurance, y compris le fichier.');
    return ok;
  }
  void _closeDrawerIfOpen() {
    final s = Scaffold.maybeOf(context);
    if (s?.isDrawerOpen ?? false) Navigator.of(context).pop();
  }

  void _go(String route) {
    _closeDrawerIfOpen();
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return; // évite de recharger la même page
    Navigator.of(context).pushReplacementNamed(route);
  }

  bool _validateCarteRequired() {
    if (_cgId == null &&
        (_cgNumeroCarteCtrl.text
            .trim()
            .isEmpty &&
            _cgProprietaireCtrl.text
                .trim()
                .isEmpty &&
            _cgMontantCtrl.text
                .trim()
                .isEmpty &&
            _cgDateDebut == null &&
            _cgDateFin == null &&
            _cgDatePaiement == null &&
            _cgDateProchainPaiement == null &&
            (_cgFichierUrl ?? '').isEmpty)) return true;

    final ok = _cgNumeroCarteCtrl.text
        .trim()
        .isNotEmpty &&
        _cgProprietaireCtrl.text
            .trim()
            .isNotEmpty &&
        _cgMontantCtrl.text
            .trim()
            .isNotEmpty &&
        _cgDateDebut != null &&
        _cgDateFin != null &&
        _cgDatePaiement != null &&
        _cgDateProchainPaiement != null &&
        (_cgFichierUrl ?? '').isNotEmpty;
    if (!ok) _toast(
        'Remplis tous les champs de la carte grise, y compris le fichier.');
    return ok;
  }

  bool _validateVignetteRequired() {
    if (_vignetteId == null &&
        (_vAnneeFiscaleCtrl.text
            .trim()
            .isEmpty &&
            _vNumeroQuitanceCtrl.text
                .trim()
                .isEmpty &&
            _vMontantCtrl.text
                .trim()
                .isEmpty &&
            _vDateDebut == null &&
            _vDateFin == null &&
            _vDatePaiement == null &&
            _vDateProchainPaiement == null &&
            (_vFichierUrl ?? '').isEmpty)) return true;

    final ok = _vAnneeFiscaleCtrl.text
        .trim()
        .isNotEmpty &&
        _vNumeroQuitanceCtrl.text
            .trim()
            .isNotEmpty &&
        _vMontantCtrl.text
            .trim()
            .isNotEmpty &&
        _vDateDebut != null &&
        _vDateFin != null &&
        _vDatePaiement != null &&
        _vDateProchainPaiement != null &&
        (_vFichierUrl ?? '').isNotEmpty;
    if (!ok) _toast(
        'Remplis tous les champs de la vignette, y compris le fichier.');
    return ok;
  }

  // ✅ NEW : validation Taxe (souple si rien n’est saisi)
  bool _validateTaxeRequired() {
    if (_taxeId == null &&
        (_taxeTypeCtrl.text
            .trim()
            .isEmpty &&
            _taxeMontantCtrl.text
                .trim()
                .isEmpty &&
            _taxeDateDebut == null &&
            _taxeDateFin == null &&
            _taxeDatePaiement == null &&
            _taxeDateProchainPaiement == null &&
            (_taxeFichierUrl ?? '').isEmpty)) return true;

    final ok = _taxeTypeCtrl.text
        .trim()
        .isNotEmpty &&
        _taxeMontantCtrl.text
            .trim()
            .isNotEmpty &&
        _taxeDateDebut != null &&
        _taxeDateFin != null &&
        _taxeDatePaiement != null &&
        _taxeDateProchainPaiement != null &&
        (_taxeFichierUrl ?? '').isNotEmpty;
    if (!ok) _toast(
        'Remplis tous les champs de la taxe, y compris le fichier.');
    return ok;
  }

  // ====== API (PUT/POST) ======
  Future<void> _putVoiture() async {
    // Conversion carburant String → int (côté backend c’est un enum)
    final carburantMap = {
      'Essence': 0,
      'Diesel': 1,
      'Hybride': 2,
      'Electrique': 3,
    };

    final payload = {
      'id': _voitureId,
      'matricule': _matriculeCtrl.text.trim(),
      'societeId': _selectedSocieteId,
      'marque': _marqueCtrl.text.trim(),
      'modele': _modeleCtrl.text.trim(),
      'annee': int.tryParse(_anneeCtrl.text.trim()),
      'numeroChassis': _numeroChassisCtrl.text.trim(),
      'kilometrage': int.tryParse(_kilometrageCtrl.text.trim()),
      'prixAchat': double.tryParse(_prixAchatCtrl.text.trim()),
      'dateAchat': _dateAchat?.toIso8601String(),
      'active': _active,
      'numInterne': _numInterneCtrl.text.trim().isEmpty
          ? null
          : _numInterneCtrl.text.trim(),
      'saisie': _saisieEffectuee,
      'occupee': _occupee ?? 'Libre',
      'carburant': carburantMap[_carburant] ?? 0, // int attendu par backend
    };

    await _putJson('Voitures/${_voitureId}', payload);
    _toast('Voiture mise à jour ✔');
  }

  Future<void> _upsertAssurance() async {
    if (!_validateAssuranceRequired()) return;
    if (_assuranceId != null) {
      final payload = {
        'id': _assuranceId,
        'voitureId': _voitureId,
        'compagnie': _assuranceCompagnieCtrl.text.trim(),
        'numeroPolice': _assuranceNumeroPoliceCtrl.text.trim(),
        'tousRisques': _assuranceTousRisques,
        'dateDebut': _assuranceDebut?.toIso8601String(),
        'dateFin': _assuranceFin?.toIso8601String(),
        'montant': double.tryParse(_assuranceMontantCtrl.text.trim()),
        'datePaiement': _assuranceDatePaiement?.toIso8601String(),
        'dateProchainPaiement': _assuranceDateProchainPaiement
            ?.toIso8601String(),
        'fichierUrl': _assuranceFichierUrl,
        'notes': _assuranceNotesCtrl.text
            .trim()
            .isEmpty ? null : _assuranceNotesCtrl.text.trim(),
      };
      await _putJson('Assurances/$_assuranceId', payload);
    } else if ((_assuranceFichierUrl ?? '').isNotEmpty) {
      final payload = {
        'voitureId': _voitureId,
        'compagnie': _assuranceCompagnieCtrl.text.trim(),
        'numeroPolice': _assuranceNumeroPoliceCtrl.text.trim(),
        'tousRisques': _assuranceTousRisques,
        'dateDebut': _assuranceDebut?.toIso8601String(),
        'dateFin': _assuranceFin?.toIso8601String(),
        'montant': double.tryParse(_assuranceMontantCtrl.text.trim()),
        'datePaiement': _assuranceDatePaiement?.toIso8601String(),
        'dateProchainPaiement': _assuranceDateProchainPaiement
            ?.toIso8601String(),
        'fichierUrl': _assuranceFichierUrl,
        'notes': _assuranceNotesCtrl.text
            .trim()
            .isEmpty ? null : _assuranceNotesCtrl.text.trim(),
      };
      await _postJson('Assurances', payload);
    }
  }

  Future<void> _upsertCarteGrise() async {
    if (!_validateCarteRequired()) return;
    if (_cgId != null) {
      final payload = {
        'id': _cgId,
        'voitureId': _voitureId,
        'numeroCarte': _cgNumeroCarteCtrl.text.trim(),
        'proprietaireLegal': _cgProprietaireCtrl.text.trim(),
        'dateDebut': _cgDateDebut?.toIso8601String(),
        'dateFin': _cgDateFin?.toIso8601String(),
        'montant': double.tryParse(_cgMontantCtrl.text.trim()),
        'datePaiement': _cgDatePaiement?.toIso8601String(),
        'dateProchainPaiement': _cgDateProchainPaiement?.toIso8601String(),
        'fichierUrl': _cgFichierUrl,
        'notes': _cgNotesCtrl.text
            .trim()
            .isEmpty ? null : _cgNotesCtrl.text.trim(),
      };
      await _putJson('CartesGrises/$_cgId', payload);
    } else if ((_cgFichierUrl ?? '').isNotEmpty) {
      final payload = {
        'voitureId': _voitureId,
        'numeroCarte': _cgNumeroCarteCtrl.text.trim(),
        'proprietaireLegal': _cgProprietaireCtrl.text.trim(),
        'dateDebut': _cgDateDebut?.toIso8601String(),
        'dateFin': _cgDateFin?.toIso8601String(),
        'montant': double.tryParse(_cgMontantCtrl.text.trim()),
        'datePaiement': _cgDatePaiement?.toIso8601String(),
        'dateProchainPaiement': _cgDateProchainPaiement?.toIso8601String(),
        'fichierUrl': _cgFichierUrl,
        'notes': _cgNotesCtrl.text
            .trim()
            .isEmpty ? null : _cgNotesCtrl.text.trim(),
      };
      await _postJson('CartesGrises', payload);
    }
  }

  Future<void> _upsertVignette() async {
    if (!_validateVignetteRequired()) return;
    if (_vignetteId != null) {
      final payload = {
        'id': _vignetteId,
        'voitureId': _voitureId,
        'anneeFiscale': int.tryParse(_vAnneeFiscaleCtrl.text.trim()),
        'numeroQuitance': _vNumeroQuitanceCtrl.text.trim(),
        'dateDebut': _vDateDebut?.toIso8601String(),
        'dateFin': _vDateFin?.toIso8601String(),
        'montant': double.tryParse(_vMontantCtrl.text.trim()),
        'datePaiement': _vDatePaiement?.toIso8601String(),
        'dateProchainPaiement': _vDateProchainPaiement?.toIso8601String(),
        'fichierUrl': _vFichierUrl,
        'notes': _vNotesCtrl.text
            .trim()
            .isEmpty ? null : _vNotesCtrl.text.trim(),
      };
      await _putJson('Vignettes/$_vignetteId', payload);
    } else if ((_vFichierUrl ?? '').isNotEmpty) {
      final payload = {
        'voitureId': _voitureId,
        'anneeFiscale': int.tryParse(_vAnneeFiscaleCtrl.text.trim()),
        'numeroQuitance': _vNumeroQuitanceCtrl.text.trim(),
        'dateDebut': _vDateDebut?.toIso8601String(),
        'dateFin': _vDateFin?.toIso8601String(),
        'montant': double.tryParse(_vMontantCtrl.text.trim()),
        'datePaiement': _vDatePaiement?.toIso8601String(),
        'dateProchainPaiement': _vDateProchainPaiement?.toIso8601String(),
        'fichierUrl': _vFichierUrl,
        'notes': _vNotesCtrl.text
            .trim()
            .isEmpty ? null : _vNotesCtrl.text.trim(),
      };
      await _postJson('Vignettes', payload);
    }
  }

  // ✅ NEW : upsert Taxe
  Future<void> _upsertTaxe() async {
    if (!_validateTaxeRequired()) return;
    final payloadBody = {
      'voitureId': _voitureId,
      'libelle': _taxeTypeCtrl.text.trim(), // <-- correspond au DTO côté .NET
      'dateDebut': _taxeDateDebut?.toIso8601String(),
      'dateFin': _taxeDateFin?.toIso8601String(),
      'montant': double.tryParse(_taxeMontantCtrl.text.trim()),
      'datePaiement': _taxeDatePaiement?.toIso8601String(),
      'dateProchainPaiement': _taxeDateProchainPaiement?.toIso8601String(),
      'fichierUrl': _taxeFichierUrl,
      'notes': _taxeNotesCtrl.text
          .trim()
          .isEmpty ? null : _taxeNotesCtrl.text.trim(),
    };

    if (_taxeId != null) {
      final p = {'id': _taxeId, ...payloadBody};
      await _putJson('Taxes/$_taxeId', p);
    } else if ((_taxeFichierUrl ?? '').isNotEmpty) {
      await _postJson('Taxes', payloadBody);
    }
  }

  // ====== Success dialog ======
  Future<void> _showSuccessAndBackToDetails() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Succès'),
            content: const Text(
                'La voiture et ses documents ont été mis à jour.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'))
            ],
          ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ====== Navigation Stepper ======
  Future<void> _onContinue() async {
    try {
      setState(() => _busy = true);

      // 0: Voiture, 1: Assurance, 2: Carte, 3: Taxe, 4: Vignette
      if (_currentStep == 0) {
        if (_formVoiture.currentState!.validate() &&
            _validateVoitureRequired()) {
          await _putVoiture();
          _toast('Voiture mise à jour');
          setState(() => _currentStep = 1);
        }
      } else if (_currentStep == 1) {
        if (_validateAssuranceRequired()) {
          await _upsertAssurance();
          _toast('Assurance enregistrée');
          setState(() => _currentStep = 2);
        }
      } else if (_currentStep == 2) {
        if (_validateCarteRequired()) {
          await _upsertCarteGrise();
          _toast('Carte grise enregistrée');
          setState(() => _currentStep = 3);
        }
      } else if (_currentStep == 3) {
        if (_validateTaxeRequired()) {
          await _upsertTaxe();
          _toast('Taxe enregistrée');
          setState(() => _currentStep = 4);
        }
      } else if (_currentStep == 4) {
        if (_validateVignetteRequired()) {
          await _upsertVignette();
          _toast('Vignette enregistrée');
          await _showSuccessAndBackToDetails();
        }
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?.toString() ?? e.message ??
          'Erreur réseau';
      _toast(msg);
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onBack() {
    if (_currentStep == 0) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _currentStep -= 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeNow = ModalRoute
        .of(context)
        ?.settings
        .name ?? AppRoutes.voituresEdit;

    final sections = AppMenu.buildDefaultSections(
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBarWithMenu(
        title: 'Modifier voiture',
        onNavigate: _go,
        sections: sections,
        activeRoute: routeNow,
      ),
      drawer: AppSideMenu(
        activeRoute: routeNow,
        sections: sections,
        onNavigate: _go,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const BrandBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Card(
                  color: const Color(0xFF121214).withOpacity(.55),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: AppColors.kBg3),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Column(
                      children: [
                        if (_busy) const LinearProgressIndicator(minHeight: 2),
                        Expanded(
                          child: Stepper(
                            type: StepperType.horizontal,
                            currentStep: _currentStep,
                            onStepContinue: _onContinue,
                            onStepCancel: _onBack,
                            // ✅ Navigation libre par tap
                            onStepTapped: (idx) =>
                                setState(() => _currentStep = idx),
                            controlsBuilder: (context, details) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _busy ? null : details
                                          .onStepContinue,
                                      icon: const Icon(Icons.save),
                                      label: Text(_currentStep == 4
                                          ? 'Enregistrer'
                                          : 'Continuer'),
                                    ),
                                    const SizedBox(width: 12),
                                    TextButton.icon(
                                      onPressed: _busy ? null : details
                                          .onStepCancel,
                                      icon: const Icon(Icons.arrow_back),
                                      label: const Text('Retour'),
                                    ),
                                    const Spacer(),
                                    // ✅ Bouton "Terminer" rapide pour enregistrer UNIQUEMENT l’étape courante
                                    OutlinedButton.icon(
                                      onPressed: _busy ? null : () async {
                                        try {
                                          setState(() => _busy = true);
                                          switch (_currentStep) {
                                            case 0:
                                              if (_formVoiture.currentState!
                                                  .validate() &&
                                                  _validateVoitureRequired()) {
                                                await _putVoiture();
                                                _toast('Voiture mise à jour');
                                              }
                                              break;
                                            case 1:
                                              if (_validateAssuranceRequired()) {
                                                await _upsertAssurance();
                                                _toast('Assurance enregistrée');
                                              }
                                              break;
                                            case 2:
                                              if (_validateCarteRequired()) {
                                                await _upsertCarteGrise();
                                                _toast(
                                                    'Carte grise enregistrée');
                                              }
                                              break;
                                            case 3:
                                              if (_validateTaxeRequired()) {
                                                await _upsertTaxe();
                                                _toast('Taxe enregistrée');
                                              }
                                              break;
                                            case 4:
                                              if (_validateVignetteRequired()) {
                                                await _upsertVignette();
                                                _toast('Vignette enregistrée');
                                              }
                                              break;
                                          }
                                        } finally {
                                          if (mounted) setState(() =>
                                          _busy = false);
                                        }
                                      },
                                      icon: const Icon(
                                          Icons.check_circle_outline),
                                      label: const Text(
                                          'Enregistrer cette étape'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            steps: [
                              Step(
                                title: const Text('Voiture'),
                                isActive: _currentStep >= 0,
                                state: _currentStep > 0
                                    ? StepState.complete
                                    : StepState.indexed,
                                content: Form(key: _formVoiture,
                                    child: _buildVoitureForm()),
                              ),
                              Step(
                                title: const Text('Assurance'),
                                isActive: _currentStep >= 1,
                                state: _currentStep > 1
                                    ? StepState.complete
                                    : StepState.indexed,
                                content: Form(key: _formAssurance,
                                    child: _buildAssuranceForm()),
                              ),
                              Step(
                                title: const Text('Carte grise'),
                                isActive: _currentStep >= 2,
                                state: _currentStep > 2
                                    ? StepState.complete
                                    : StepState.indexed,
                                content: Form(key: _formCarteGrise,
                                    child: _buildCarteGriseForm()),
                              ),
                              // ✅ NEW : Step Taxe
                              Step(
                                title: const Text('Taxe'),
                                isActive: _currentStep >= 3,
                                state: _currentStep > 3
                                    ? StepState.complete
                                    : StepState.indexed,
                                content: Form(
                                    key: _formTaxe, child: _buildTaxeForm()),
                              ),
                              Step(
                                title: const Text('Vignette'),
                                isActive: _currentStep >= 4,
                                state: StepState.indexed,
                                content: Form(key: _formVignette,
                                    child: _buildVignetteForm()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====== FORMS ======
  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFF1A1A1E),
      labelStyle: const TextStyle(color: AppColors.onDark60),
      hintStyle: const TextStyle(color: AppColors.onDark40),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.kBg3)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.kOrange, width: 1.4)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Future<DateTime?> _pickDate(DateTime? initial) async {
    final now = DateTime.now();
    return await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 5),
    );
  }

  void _toast(String s) {
    if (s
        .trim()
        .isEmpty) s = 'Une erreur est survenue.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  // ✅ Preview image helper
  Widget _previewImageBox(String? absUrl, {double height = 120}) {
    if (absUrl == null || absUrl.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        color: Colors.black26,
        child: const Text('Prévisualisation indisponible'),
      );
    }
    final alt = _uploadsFallback(absUrl);
    Widget placeholder([String? msg]) =>
        Container(
          height: height,
          alignment: Alignment.center,
          color: Colors.black26,
          child: Text(msg ?? 'Prévisualisation indisponible'),
        );
    return Image.network(
      absUrl,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        if (alt == absUrl) return placeholder();
        return Image.network(
          alt,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder(),
        );
      },
    );
  }

  // ✅ Formulaire Voiture
  Widget _buildVoitureForm() {
    return LayoutBuilder(builder: (context, c) {
      final twoCols = c.maxWidth >= 720;
      Widget field(Widget w) =>
          twoCols ? SizedBox(width: (c.maxWidth - 24) / 2, child: w) : w;

      return Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          field(TextFormField(
            controller: _matriculeCtrl,
            decoration: _dec('Immatriculation *', hint: 'Ex: 1234-أ-56'),
            validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(DropdownButtonFormField<int>(
            value: _selectedSocieteId,
            decoration: _dec('Société *'),
            items: _societes
                .map((s) => DropdownMenuItem<int>(
              value: s.id,
              child: Text('${s.nom}  (ID: ${s.id})'),
            ))
                .toList(),
            onChanged: (v) => setState(() => _selectedSocieteId = v),
            validator: (v) => v == null ? 'Obligatoire' : null,
          )),
          if (_loadingSocietes)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          field(TextFormField(
            controller: _marqueCtrl,
            decoration: _dec('Marque *'),
            validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(TextFormField(
            controller: _modeleCtrl,
            decoration: _dec('Modèle *'),
            validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(TextFormField(
            controller: _anneeCtrl,
            keyboardType: TextInputType.number,
            decoration: _dec('Année *'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Obligatoire';
              final n = int.tryParse(v);
              if (n == null || n < 1980 || n > DateTime.now().year + 1) {
                return 'Année invalide';
              }
              return null;
            },
          )),
          field(TextFormField(
            controller: _numeroChassisCtrl,
            decoration: _dec('Numéro de châssis *'),
            validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(TextFormField(
            controller: _kilometrageCtrl,
            keyboardType: TextInputType.number,
            decoration: _dec('Kilométrage *'),
            validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(TextFormField(
            controller: _prixAchatCtrl,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Prix d\'achat (TND) *'),
            validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(TextFormField(
            controller: _numInterneCtrl,
            decoration: _dec('Numéro interne'),
          )),

          // ✅ Fixe pour éviter le crash quand _occupee != "Libre" ou "Occupée"
          field(DropdownButtonFormField<String>(
            value: _occupee,
            decoration: _dec('État d’occupation *'),
            items: [
              const DropdownMenuItem(value: 'Libre', child: Text('Libre')),
              const DropdownMenuItem(value: 'Occupée', child: Text('Occupée')),
              if (_occupee != null &&
                  !['Libre', 'Occupée'].contains(_occupee!))
                DropdownMenuItem(value: _occupee, child: Text(_occupee!)),
            ],
            onChanged: (v) => setState(() => _occupee = v),
            validator: (v) => v == null ? 'Obligatoire' : null,
          )),

          field(DropdownButtonFormField<String>(
            value: _carburant,
            decoration: _dec('Carburant *'),
            items: const [
              DropdownMenuItem(value: 'Essence', child: Text('Essence')),
              DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
              DropdownMenuItem(value: 'Hybride', child: Text('Hybride')),
              DropdownMenuItem(value: 'Electrique', child: Text('Électrique')),
            ],
            onChanged: (v) => setState(() => _carburant = v),
            validator: (v) => v == null ? 'Obligatoire' : null,
          )),

          field(InputDecorator(
            decoration: _dec('Date d\'achat *'),
            child: InkWell(
              onTap: () async {
                final d = await _pickDate(_dateAchat);
                if (d != null) setState(() => _dateAchat = d);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _dateAchat == null
                      ? 'Choisir une date'
                      : _dateAchat!.toIso8601String().split('T').first,
                ),
              ),
            ),
          )),

          SwitchListTile(
            title:
            const Text('Active', style: TextStyle(color: Colors.white70)),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          SwitchListTile(
            title: const Text('Saisie effectuée',
                style: TextStyle(color: Colors.white70)),
            subtitle: const Text(
              'Marquer si la saisie documentaire est complète',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            value: _saisieEffectuee,
            onChanged: (v) => setState(() => _saisieEffectuee = v),
            activeColor: Colors.orangeAccent,
          ),
        ],
      );
    });
  }

  // ✅ Formulaire Assurance
  Widget _buildAssuranceForm() {
    return LayoutBuilder(builder: (context, c) {
      final twoCols = c.maxWidth >= 720;
      Widget field(Widget w) =>
          twoCols ? SizedBox(width: (c.maxWidth - 24) / 2, child: w) : w;
      final isImg = _looksLikeImage(_assurancePreviewUrl);

      return Wrap(
        spacing: 24, runSpacing: 12,
        children: [
          field(TextFormField(controller: _assuranceCompagnieCtrl,
              decoration: _dec('Compagnie *'))),
          field(TextFormField(controller: _assuranceNumeroPoliceCtrl,
              decoration: _dec('Numéro de police *'))),
          field(SwitchListTile(
            title: const Text(
                'Tous risques', style: TextStyle(color: Colors.white70)),
            value: _assuranceTousRisques,
            onChanged: (v) => setState(() => _assuranceTousRisques = v),
          )),
          field(TextFormField(
            controller: _assuranceMontantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Montant (TND) *'),
          )),
          field(_dateField('Date début', _assuranceDebut, (d) =>
              setState(() => _assuranceDebut = d))),
          field(_dateField('Date fin', _assuranceFin, (d) =>
              setState(() => _assuranceFin = d))),
          field(_dateField('Date paiement', _assuranceDatePaiement, (d) =>
              setState(() => _assuranceDatePaiement = d))),
          field(_dateField(
              'Prochain paiement', _assuranceDateProchainPaiement, (d) =>
              setState(() => _assuranceDateProchainPaiement = d))),
          field(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fichier (image/pdf)',
                  style: TextStyle(color: AppColors.onDark60)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final up = await _uploadFile(category: 'assurances');
                  if (up != null) {
                    setState(() {
                      _assuranceFichierUrl = up.rawUrl;
                      _assurancePreviewUrl = up.previewUrl;
                    });
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Choisir & téléverser'),
              ),
              if (isImg) Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: _previewImageBox(_assurancePreviewUrl)),
              ),
            ],
          )),
          field(TextFormField(controller: _assuranceNotesCtrl,
              decoration: _dec('Notes'),
              maxLines: 2)),
        ],
      );
    });
  }

  // ✅ Formulaire Carte Grise
  Widget _buildCarteGriseForm() {
    return LayoutBuilder(builder: (context, c) {
      final twoCols = c.maxWidth >= 720;
      Widget field(Widget w) =>
          twoCols ? SizedBox(width: (c.maxWidth - 24) / 2, child: w) : w;
      final isImg = _looksLikeImage(_cgPreviewUrl);

      return Wrap(
        spacing: 24, runSpacing: 12,
        children: [
          field(TextFormField(controller: _cgNumeroCarteCtrl,
              decoration: _dec('Numéro carte grise *'))),
          field(TextFormField(controller: _cgProprietaireCtrl,
              decoration: _dec('Propriétaire légal *'))),
          field(TextFormField(
            controller: _cgMontantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Montant (TND) *'),
          )),
          field(_dateField('Date début', _cgDateDebut, (d) =>
              setState(() => _cgDateDebut = d))),
          field(_dateField(
              'Date fin', _cgDateFin, (d) => setState(() => _cgDateFin = d))),
          field(_dateField('Date paiement', _cgDatePaiement, (d) =>
              setState(() => _cgDatePaiement = d))),
          field(_dateField('Prochain paiement', _cgDateProchainPaiement, (d) =>
              setState(() => _cgDateProchainPaiement = d))),
          field(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fichier (image/pdf)',
                  style: TextStyle(color: AppColors.onDark60)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final up = await _uploadFile(category: 'cartes-grises');
                  if (up != null) {
                    setState(() {
                      _cgFichierUrl = up.rawUrl;
                      _cgPreviewUrl = up.previewUrl;
                    });
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Choisir & téléverser'),
              ),
              if (isImg) Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: _previewImageBox(_cgPreviewUrl)),
              ),
            ],
          )),
          field(TextFormField(controller: _cgNotesCtrl,
              decoration: _dec('Notes'),
              maxLines: 2)),
        ],
      );
    });
  }

  // ✅ Formulaire Vignette
  Widget _buildVignetteForm() {
    return LayoutBuilder(builder: (context, c) {
      final twoCols = c.maxWidth >= 720;
      Widget field(Widget w) =>
          twoCols ? SizedBox(width: (c.maxWidth - 24) / 2, child: w) : w;
      final isImg = _looksLikeImage(_vPreviewUrl);

      return Wrap(
        spacing: 24, runSpacing: 12,
        children: [
          field(TextFormField(controller: _vAnneeFiscaleCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec('Année fiscale *'))),
          field(TextFormField(controller: _vNumeroQuitanceCtrl,
              decoration: _dec('Numéro quittance *'))),
          field(TextFormField(
            controller: _vMontantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Montant (TND) *'),
          )),
          field(_dateField('Date début', _vDateDebut, (d) =>
              setState(() => _vDateDebut = d))),
          field(_dateField(
              'Date fin', _vDateFin, (d) => setState(() => _vDateFin = d))),
          field(_dateField('Date paiement', _vDatePaiement, (d) =>
              setState(() => _vDatePaiement = d))),
          field(_dateField('Prochain paiement', _vDateProchainPaiement, (d) =>
              setState(() => _vDateProchainPaiement = d))),
          field(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fichier (image/pdf)',
                  style: TextStyle(color: AppColors.onDark60)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final up = await _uploadFile(category: 'vignettes');
                  if (up != null) {
                    setState(() {
                      _vFichierUrl = up.rawUrl;
                      _vPreviewUrl = up.previewUrl;
                    });
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Choisir & téléverser'),
              ),
              if (isImg) Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: _previewImageBox(_vPreviewUrl)),
              ),
            ],
          )),
          field(TextFormField(
              controller: _vNotesCtrl, decoration: _dec('Notes'), maxLines: 2)),
        ],
      );
    });
  }

  // ✅ Formulaire Taxe
  Widget _buildTaxeForm() {
    return LayoutBuilder(builder: (context, c) {
      final twoCols = c.maxWidth >= 720;
      Widget field(Widget w) =>
          twoCols ? SizedBox(width: (c.maxWidth - 24) / 2, child: w) : w;
      final isImg = _looksLikeImage(_taxePreviewUrl);

      return Wrap(
        spacing: 24, runSpacing: 12,
        children: [
          field(TextFormField(controller: _taxeTypeCtrl,
              decoration: _dec(
                  'Libellé taxe *', hint: 'Ex: Taxe circulation'))),
          field(TextFormField(
            controller: _taxeMontantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Montant (TND) *'),
          )),
          field(_dateField('Date début', _taxeDateDebut, (d) =>
              setState(() => _taxeDateDebut = d))),
          field(_dateField('Date fin', _taxeDateFin, (d) =>
              setState(() => _taxeDateFin = d))),
          field(_dateField('Date paiement', _taxeDatePaiement, (d) =>
              setState(() => _taxeDatePaiement = d))),
          field(_dateField(
              'Prochain paiement', _taxeDateProchainPaiement, (d) =>
              setState(() => _taxeDateProchainPaiement = d))),
          field(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fichier (image/pdf)',
                  style: TextStyle(color: AppColors.onDark60)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final up = await _uploadFile(category: 'taxes');
                  if (up != null) {
                    setState(() {
                      _taxeFichierUrl = up.rawUrl;
                      _taxePreviewUrl = up.previewUrl;
                    });
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Choisir & téléverser'),
              ),
              if (isImg) Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: _previewImageBox(_taxePreviewUrl)),
              ),
            ],
          )),
          field(TextFormField(controller: _taxeNotesCtrl,
              decoration: _dec('Notes'),
              maxLines: 2)),
        ],
      );
    });
  }

  // ✅ Helper date
  Widget _dateField(String label, DateTime? current,
      ValueChanged<DateTime> onPick) {
    return InputDecorator(
      decoration: _dec(label),
      child: InkWell(
        onTap: () async {
          final d = await _pickDate(current);
          if (d != null) onPick(d);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(current == null ? 'Choisir' : current
              .toIso8601String()
              .split('T')
              .first),
        ),
      ),
    );
  }
}
