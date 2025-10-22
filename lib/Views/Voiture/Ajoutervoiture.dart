// lib/Views/Voiture/Ajoutervoiture.dart
import 'dart:convert' as convert;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import 'package:meubcars/core/cache/cacheHelper.dart';
import 'package:meubcars/Data/Models/user_model.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/core/api/endpoints.dart';

import '../../utils/background.dart';

/// Option d'une société pour la liste déroulante
class SocieteOption {
  final int id;
  final String nom;
  const SocieteOption({required this.id, required this.nom});
}

class AjoutervoiturePage extends StatefulWidget {
  const AjoutervoiturePage({super.key});

  @override
  State<AjoutervoiturePage> createState() => _AjoutervoiturePageState();
}

class _AjoutervoiturePageState extends State<AjoutervoiturePage> {
  // ====== HTTP ======
// ====== HTTP ======
  final Dio _dio = Dio(BaseOptions(baseUrl: EndPoint.baseUrl));

  Future<Map<String, String>> _authHeaders() async {
    final token = await CacheHelper.getData(key: 'token');
    final h = <String, String>{'Accept': 'application/json'};
    if (token != null && token.toString().isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

// ✅ Laisse passer 400 pour lire l'erreur renvoyée par l'API (ModelState)
  Future<Response> _postJson(String path, Map<String, dynamic> data) async {
    final headers = await _authHeaders();
    final res = await _dio.post(
      path,
      data: data,
      options: Options(
        headers: {...headers, 'Content-Type': 'application/json'},
        validateStatus: (_) => true, // on peut lire le body même si 400
      ),
    );
    if ((res.statusCode ?? 0) >= 400) {
      final body = res.data;
      String msg = 'Requête invalide';
      if (body is Map && body['message'] != null) {
        final errs = (body['errors'] as Iterable?)
            ?.map((e) => '${e['field']}: ${(e['messages'] as Iterable?)?.join(', ')}')
            .join(' • ');
        msg = '${body['message']}${errs == null ? '' : ' — $errs'}';
      } else if (body is String && body.trim().isNotEmpty) {
        msg = body;
      }
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        message: msg,
      );
    }
    return res;
  }

// ====== Helpers formatages ======

// ✅ Dates en "YYYY-MM-DD" (compatibles avec DateOnly côté .NET)
  String? _dateOnly(DateTime? d) => d == null ? null : d.toIso8601String().split('T').first;

// ✅ Enum Carburant en entier (évite les noms/accents)
// ⚠️ Adapte l’ordre si ton enum serveur est différent
  int? _carburantCode() {
    const map = {
      'Essence': 0,
      'Diesel': 1,
      'Hybride': 2,
      'Electrique': 3,
    };
    return _carburant == null ? null : map[_carburant!];
  }



  // ====== COLORS / STYLES (VISIBILITÉ BOUTONS) ======
  static const _kBtnBg = Color(0xFF1E1E22); // léger contraste sur fond sombre
  static const _kBtnBorder = Color(0xFFFFA143); // proche de AppColors.kOrange
  static const _kBtnFg = Colors.white;         // texte + icône clairs

  ButtonStyle _outlinedBtnStyle() => OutlinedButton.styleFrom(
    foregroundColor: _kBtnFg,
    backgroundColor: _kBtnBg,
    side: const BorderSide(color: _kBtnBorder, width: 1.2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  ButtonStyle _elevatedBtnStyle() => ElevatedButton.styleFrom(
    foregroundColor: Colors.black,
    backgroundColor: _kBtnBorder, // bouton primaire très visible
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    elevation: 0,
  );

  ButtonStyle _textBtnStyle() => TextButton.styleFrom(
    foregroundColor: _kBtnBorder, // texte orange
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

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

    final p = (port == 80 && scheme == 'http') || (port == 443 && scheme == 'https') ? '' : ':$port';
    return '$scheme://$host$p';
  }

  String _encodeSegments(String path) {
    final leadingSlash = path.startsWith('/');
    final parts = path.split('/');
    final encoded = <String>[];

    for (var seg in parts) {
      if (seg.isEmpty) {
        encoded.add('');
        continue;
      }
      seg = seg.replaceAllMapped(RegExp(r'%(?![0-9A-Fa-f]{2})'), (_) => '%25');
      seg = seg.replaceAll(' ', '%20').replaceAll('#', '%23');
      encoded.add(seg);
    }

    final joined = encoded.join('/');
    return leadingSlash && !joined.startsWith('/') ? '/$joined' : joined;
  }

  String _absoluteFrom(String urlOrPath) {
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      try {
        final u = Uri.parse(urlOrPath);
        var scheme = u.scheme;
        var host = u.host;
        final port = u.hasPort ? u.port : null;

        if (!kIsWeb && Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
          host = '10.0.2.2';
          if (scheme == 'https') scheme = 'http';
        }

        return Uri(
          scheme: scheme,
          host: host,
          port: port,
          path: _encodeSegments(u.path.isEmpty ? '/' : u.path),
          query: u.hasQuery ? u.query : null,
        ).toString();
      } catch (_) {
        var fixed = urlOrPath;
        if (!kIsWeb && Platform.isAndroid) {
          fixed = fixed.replaceFirst(RegExp(r'^https?://(localhost|127\.0\.0\.1)'), 'http://10.0.2.2');
          fixed = fixed.replaceFirst(RegExp(r'^https://10\.0\.2\.2'), 'http://10.0.2.2');
        }
        final needle = '://';
        final i = fixed.indexOf(needle);
        if (i > -1) {
          final slash = fixed.indexOf('/', i + needle.length);
          if (slash > -1) {
            final base = fixed.substring(0, slash);
            final rest = fixed.substring(slash);
            return '$base${_encodeSegments(rest)}';
          }
        }
        return fixed;
      }
    }

    final origin = _apiOrigin();
    String p = urlOrPath.isEmpty ? urlOrPath : (urlOrPath.startsWith('/') ? urlOrPath : '/$urlOrPath');
    p = p.replaceAll(RegExp(r'/{2,}'), '/');
    return '$origin${_encodeSegments(p)}';
  }

  String _uploadsFallback(String absUrl) {
    final needle = '://';
    final i = absUrl.indexOf(needle);
    if (i < 0) return absUrl;
    final hostPartEnd = absUrl.indexOf('/', i + needle.length);
    if (hostPartEnd < 0) return absUrl;

    final host = absUrl.substring(0, hostPartEnd);
    final path = absUrl.substring(hostPartEnd);

    if (RegExp(r'^/uploads/(?!uploads/)', caseSensitive: false).hasMatch(path)) {
      return '$host' + path.replaceFirst(RegExp(r'^/uploads/', caseSensitive: false), '/uploads/uploads/');
    }
    return absUrl;
  }

  bool _looksLikeImage(String? url) {
    final s = (url ?? '').toLowerCase();
    return s.endsWith('.png') || s.endsWith('.jpg') || s.endsWith('.jpeg') ||
        s.contains('.png?') || s.contains('.jpg?') || s.contains('.jpeg?');
  }

  // ====== Stepper state ======
  int _currentStep = 0;
  bool _busy = false;
  int? _voitureId;

  // ====== Forms keys ======
  final _formVoiture = GlobalKey<FormState>();
  final _formAssurance = GlobalKey<FormState>();
  final _formCarteGrise = GlobalKey<FormState>();
  final _formVignette = GlobalKey<FormState>();
  final _formTaxe = GlobalKey<FormState>();       // NEW
  final _formVisite = GlobalKey<FormState>();

  // ====== Sociétés (liste depuis l'API) ======
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
  bool _saisie = false;
  final _numInterneCtrl = TextEditingController();
  final _occupeeCtrl = TextEditingController();

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
  String? _assuranceFichierUrl;   // API
  String? _assurancePreviewUrl;   // Preview

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

  // ====== Taxe ======  // NEW
  final _tLibelleCtrl = TextEditingController();
  final _tMontantCtrl = TextEditingController();
  DateTime? _tDateDebut;
  DateTime? _tDateFin;
  DateTime? _tDatePaiement;
  DateTime? _tDateProchainPaiement;
  String? _tFichierUrl;
  String? _tPreviewUrl;
  final _tNotesCtrl = TextEditingController();

  // ====== Visite technique ======
  final _vtCentreCtrl = TextEditingController();
  final _vtNumeroRapportCtrl = TextEditingController();
  final _vtMontantCtrl = TextEditingController();
  DateTime? _vtDateDebut;
  DateTime? _vtDateFin;
  DateTime? _vtDatePaiement;
  DateTime? _vtDateProchainPaiement;
  bool _vtContreVisite = false;
  String? _vtFichierUrl;
  String? _vtPreviewUrl;
  final _vtNotesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSocietes();
  }

  Future<void> _fetchSocietes() async {
    try {
      setState(() => _loadingSocietes = true);
      final headers = await _authHeaders();
      final res = await _dio.get('Societes', options: Options(headers: headers));

      final raw = res.data;
      final List<dynamic> list = raw is List ? raw : <dynamic>[];

      final parsed = list.map<SocieteOption>((dynamic item) {
        final m = (item as Map).map<String, dynamic>((k, v) => MapEntry(k.toString(), v));
        final id = (m['id'] ?? m['Id']) as int? ?? (m['id'] as num?)?.toInt() ?? (m['Id'] as num?)?.toInt() ?? 0;
        final nomRaw = m['nom'] ?? m['Nom'] ?? m['name'] ?? m['Name'] ?? '';
        final nom = nomRaw?.toString() ?? '';
        return SocieteOption(id: id, nom: nom.isEmpty ? 'Société #$id' : nom);
      }).where((s) => s.id != 0).toList();

      setState(() {
        _societes = parsed;
        if (_societes.length == 1) _selectedSocieteId = _societes.first.id;
      });
    } catch (e) {
      _toast('Impossible de charger les sociétés');
    } finally {
      if (mounted) setState(() => _loadingSocietes = false);
    }
  }

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
      _tLibelleCtrl,
      _tMontantCtrl,
      _tNotesCtrl,
      _vtCentreCtrl,
      _vtNumeroRapportCtrl,
      _vtMontantCtrl,
      _vtNotesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ====== NAV helpers ======
  void _closeDrawerIfOpen() {
    final s = Scaffold.maybeOf(context);
    if (s?.isDrawerOpen ?? false) Navigator.of(context).pop();
  }

  void _go(String route) {
    _closeDrawerIfOpen();
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  // ====== UI utils ======
  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFF1A1A1E),
      labelStyle: const TextStyle(color: AppColors.onDark60),
      hintStyle: const TextStyle(color: AppColors.onDark40),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.kBg3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.kOrange, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
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
    if (s.trim().isEmpty) s = 'Une erreur est survenue.';
    // ignore: avoid_print
    print('[SnackBar] $s');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  // ====== Upload helper (returns raw server url + absolute preview) ======
  Future<({String rawUrl, String previewUrl})?> _uploadFile({
    required String category,
  }) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (picked == null || picked.files.isEmpty) return null;

      final f = picked.files.single;
      MultipartFile filePart;

      final ext = (f.extension ?? '').toLowerCase();
      final mime = ext == 'pdf'
          ? 'application/pdf'
          : (ext == 'jpg' || ext == 'jpeg')
          ? 'image/jpeg'
          : 'image/png';

      if (f.bytes != null) {
        filePart = MultipartFile.fromBytes(
          f.bytes!,
          filename: f.name,
          contentType: MediaType.parse(mime),
        );
      } else if (f.path != null) {
        filePart = await MultipartFile.fromFile(
          f.path!,
          filename: f.name,
          contentType: MediaType.parse(mime),
        );
      } else {
        _toast('Impossible de lire le fichier sélectionné.');
        return null;
      }

      final form = FormData.fromMap({'file': filePart, 'category': category});
      final headers = await _authHeaders();
      final res = await _dio.post('Uploads', data: form, options: Options(headers: headers));

      final data = res.data is Map ? (res.data as Map) : {};
      final raw = (data['url'] ?? data['path'] ?? data['fileUrl'] ?? '').toString();
      if (raw.isEmpty) {
        _toast('Réponse upload invalide: ${res.data}');
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

  // ====== Validations by step ======
  bool _validateVoitureRequired() {
    final ok = _matriculeCtrl.text.trim().isNotEmpty &&
        _selectedSocieteId != null &&
        _marqueCtrl.text.trim().isNotEmpty &&
        _modeleCtrl.text.trim().isNotEmpty &&
        _anneeCtrl.text.trim().isNotEmpty &&
        _numeroChassisCtrl.text.trim().isNotEmpty &&
        _kilometrageCtrl.text.trim().isNotEmpty &&
        _prixAchatCtrl.text.trim().isNotEmpty &&
        _carburant != null &&
        _dateAchat != null;
    if (!ok) _toast('Complète tous les champs de la voiture.');
    return ok;
  }

  bool _validateAssuranceRequired() {
    final ok = _assuranceCompagnieCtrl.text.trim().isNotEmpty &&
        _assuranceNumeroPoliceCtrl.text.trim().isNotEmpty &&
        _assuranceMontantCtrl.text.trim().isNotEmpty &&
        _assuranceDebut != null &&
        _assuranceFin != null &&
        _assuranceDatePaiement != null &&
        _assuranceDateProchainPaiement != null &&
        (_assuranceFichierUrl ?? '').isNotEmpty;
    if (!ok) _toast('Remplis tous les champs de l’assurance, y compris le fichier.');
    return ok;
  }

  bool _validateCarteRequired() {
    final ok = _cgNumeroCarteCtrl.text.trim().isNotEmpty &&
        _cgProprietaireCtrl.text.trim().isNotEmpty &&
        _cgMontantCtrl.text.trim().isNotEmpty &&
        _cgDateDebut != null &&
        _cgDateFin != null &&
        _cgDatePaiement != null &&
        _cgDateProchainPaiement != null &&
        (_cgFichierUrl ?? '').isNotEmpty;
    if (!ok) _toast('Remplis tous les champs de la carte grise, y compris le fichier.');
    return ok;
  }

  bool _validateVignetteRequired() {
    final ok = _vAnneeFiscaleCtrl.text.trim().isNotEmpty &&
        _vNumeroQuitanceCtrl.text.trim().isNotEmpty &&
        _vMontantCtrl.text.trim().isNotEmpty &&
        _vDateDebut != null &&
        _vDateFin != null &&
        _vDatePaiement != null &&
        _vDateProchainPaiement != null &&
        (_vFichierUrl ?? '').isNotEmpty;
    if (!ok) _toast('Remplis tous les champs de la vignette, y compris le fichier.');
    return ok;
  }

  bool _validateTaxeRequired() { // NEW
    final ok = _tLibelleCtrl.text.trim().isNotEmpty &&
        _tMontantCtrl.text.trim().isNotEmpty &&
        _tDateDebut != null &&
        _tDateFin != null &&
        _tDatePaiement != null &&
        _tDateProchainPaiement != null &&
        (_tFichierUrl ?? '').isNotEmpty;
    if (!ok) _toast('Remplis tous les champs de la taxe, y compris le fichier.');
    return ok;
  }

  bool _validateVisiteRequired() {
    final ok = _vtCentreCtrl.text.trim().isNotEmpty &&
        _vtNumeroRapportCtrl.text.trim().isNotEmpty &&
        _vtMontantCtrl.text.trim().isNotEmpty &&
        _vtDateDebut != null &&
        _vtDateFin != null &&
        _vtDatePaiement != null &&
        _vtDateProchainPaiement != null &&
        (_vtFichierUrl ?? '').isNotEmpty;
    if (!ok) _toast('Remplis tous les champs de la visite technique, y compris le fichier.');
    return ok;
  }

  // ====== API ======





// ====== API ======
  Future<int> _postVoiture() async {
    final payload = {
      'matricule': _matriculeCtrl.text.trim(),
      'societeId': _selectedSocieteId,
      'marque': _marqueCtrl.text.trim(),
      'modele': _modeleCtrl.text.trim(),
      'annee': int.tryParse(_anneeCtrl.text.trim()),
      'numeroChassis': _numeroChassisCtrl.text.trim(),
      'carburant': _carburantCode(),                 // 👈 entier
      'kilometrage': int.tryParse(_kilometrageCtrl.text.trim()),
      'dateAchat': _dateOnly(_dateAchat),            // 👈 YYYY-MM-DD
      'prixAchat': double.tryParse(_prixAchatCtrl.text.trim()),
      'active': _active,
      'saisie': _saisie,
      // Optionnels (ignorés si absents côté DTO)
      'numInterne': _numInterneCtrl.text.trim().isEmpty ? null : _numInterneCtrl.text.trim(),
      'occupee': null,
    };
    final res = await _postJson('Voitures', payload);
    final id = res.data['id'] as int?;
    if (id == null) throw Exception('Réponse invalide: id manquant');
    return id;
  }

  Future<void> _postAssurance(int voitureId) async {
    final payload = {
      'voitureId': voitureId,
      'compagnie': _assuranceCompagnieCtrl.text.trim(),
      'numeroPolice': _assuranceNumeroPoliceCtrl.text.trim(),
      'tousRisques': _assuranceTousRisques,
      'dateDebut': _dateOnly(_assuranceDebut),
      'dateFin': _dateOnly(_assuranceFin),
      'montant': double.tryParse(_assuranceMontantCtrl.text.trim()),
      'datePaiement': _dateOnly(_assuranceDatePaiement),
      'dateProchainPaiement': _dateOnly(_assuranceDateProchainPaiement),
      'fichierUrl': _assuranceFichierUrl,
      'notes': _assuranceNotesCtrl.text.trim().isEmpty ? null : _assuranceNotesCtrl.text.trim(),
    };
    await _postJson('Assurances', payload);
  }

  Future<void> _postCarteGrise(int voitureId) async {
    final payload = {
      'voitureId': voitureId,
      'numeroCarte': _cgNumeroCarteCtrl.text.trim(),
      'proprietaireLegal': _cgProprietaireCtrl.text.trim(),
      'dateDebut': _dateOnly(_cgDateDebut),
      'dateFin': _dateOnly(_cgDateFin),
      'montant': double.tryParse(_cgMontantCtrl.text.trim()),
      'datePaiement': _dateOnly(_cgDatePaiement),
      'dateProchainPaiement': _dateOnly(_cgDateProchainPaiement),
      'fichierUrl': _cgFichierUrl,
      'notes': _cgNotesCtrl.text.trim().isEmpty ? null : _cgNotesCtrl.text.trim(),
    };
    await _postJson('CartesGrises', payload);
  }

  Future<void> _postVignette(int voitureId) async {
    final payload = {
      'voitureId': voitureId,
      'anneeFiscale': int.tryParse(_vAnneeFiscaleCtrl.text.trim()),
      'numeroQuitance': _vNumeroQuitanceCtrl.text.trim(),
      'dateDebut': _dateOnly(_vDateDebut),
      'dateFin': _dateOnly(_vDateFin),
      'montant': double.tryParse(_vMontantCtrl.text.trim()),
      'datePaiement': _dateOnly(_vDatePaiement),
      'dateProchainPaiement': _dateOnly(_vDateProchainPaiement),
      'fichierUrl': _vFichierUrl,
      'notes': _vNotesCtrl.text.trim().isEmpty ? null : _vNotesCtrl.text.trim(),
    };
    await _postJson('Vignettes', payload);
  }

  Future<void> _postTaxe(int voitureId) async {
    final payload = {
      'voitureId': voitureId,
      'libelle': _tLibelleCtrl.text.trim(),
      'montant': double.tryParse(_tMontantCtrl.text.trim()),
      'dateDebut': _dateOnly(_tDateDebut),
      'dateFin': _dateOnly(_tDateFin),
      'datePaiement': _dateOnly(_tDatePaiement),
      'dateProchainPaiement': _dateOnly(_tDateProchainPaiement),
      'fichierUrl': _tFichierUrl,
      'notes': _tNotesCtrl.text.trim().isEmpty ? null : _tNotesCtrl.text.trim(),
    };
    await _postJson('Taxes', payload);
  }

  Future<void> _postVisiteTechnique(int voitureId) async {
    final payload = {
      'voitureId': voitureId,
      'centre': _vtCentreCtrl.text.trim(),
      'numeroRapport': _vtNumeroRapportCtrl.text.trim(),
      'contreVisite': _vtContreVisite,
      'dateDebut': _dateOnly(_vtDateDebut),
      'dateFin': _dateOnly(_vtDateFin),
      'montant': double.tryParse(_vtMontantCtrl.text.trim()),
      'datePaiement': _dateOnly(_vtDatePaiement),
      'dateProchainPaiement': _dateOnly(_vtDateProchainPaiement),
      'fichierUrl': _vtFichierUrl,
      'notes': _vtNotesCtrl.text.trim().isEmpty ? null : _vtNotesCtrl.text.trim(),
    };
    await _postJson('VisitesTechniques', payload);
  }

  // ====== Success dialog ======
  Future<void> _showSuccessAndGoHome() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Succès'),
        content: const Text('La voiture et ses documents ont été enregistrés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  // ====== Navigation Stepper ======
  Future<void> _onContinue() async {
    try {
      setState(() => _busy = true);

      if (_currentStep == 0) {
        if (_formVoiture.currentState!.validate() && _validateVoitureRequired()) {
          _voitureId = await _postVoiture();
          _toast('Voiture créée (#$_voitureId)');
          setState(() => _currentStep = 1);
        }
      } else if (_currentStep == 1) {
        if (_formAssurance.currentState!.validate() && _validateAssuranceRequired()) {
          if (_voitureId == null) throw Exception('voitureId manquant');
          await _postAssurance(_voitureId!);
          _toast('Assurance enregistrée');
          setState(() => _currentStep = 2);
        }
      } else if (_currentStep == 2) {
        if (_formCarteGrise.currentState!.validate() && _validateCarteRequired()) {
          if (_voitureId == null) throw Exception('voitureId manquant');
          await _postCarteGrise(_voitureId!);
          _toast('Carte grise enregistrée');
          setState(() => _currentStep = 3);
        }
      } else if (_currentStep == 3) {
        if (_formVignette.currentState!.validate() && _validateVignetteRequired()) {
          if (_voitureId == null) throw Exception('voitureId manquant');
          await _postVignette(_voitureId!);
          _toast('Vignette enregistrée');
          setState(() => _currentStep = 4); // -> Taxe
        }
      } else if (_currentStep == 4) { // NEW: Taxe
        if (_formTaxe.currentState!.validate() && _validateTaxeRequired()) {
          if (_voitureId == null) throw Exception('voitureId manquant');
          await _postTaxe(_voitureId!);
          _toast('Taxe enregistrée');
          setState(() => _currentStep = 5); // -> Visite technique
        }
      } else if (_currentStep == 5) {
        if (_formVisite.currentState!.validate() && _validateVisiteRequired()) {
          if (_voitureId == null) throw Exception('voitureId manquant');
          await _postVisiteTechnique(_voitureId!);
          _toast('Visite technique enregistrée');
          await _showSuccessAndGoHome();
        }
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?.toString() ?? e.message ?? 'Erreur réseau';
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

  // Add this helper inside your State class (above build)
  Future<UserModel?> _getCurrentUser() async {
    dynamic raw;

    // 1) Try common composite keys first
    for (final key in ['user', 'currentUser', 'profile']) {
      raw = await CacheHelper.getData(key: key);
      if (raw != null) break;
    }

    // 2) If we have a Map or JSON string, parse to UserModel
    try {
      if (raw is Map) {
        return UserModel.fromJson(Map<String, dynamic>.from(raw));
      }
      if (raw is String && raw.trim().isNotEmpty) {
        final decoded = convert.jsonDecode(raw);
        if (decoded is Map) {
          return UserModel.fromJson(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (_) {
      // ignore parsing errors, we'll try fallbacks below
    }

    // 3) Fallback: read individual fields
    final name = await CacheHelper.getData(key: 'nomComplet') ??
        await CacheHelper.getData(key: 'fullName') ??
        await CacheHelper.getData(key: 'name');

    final email = await CacheHelper.getData(key: 'email') ??
        await CacheHelper.getData(key: 'Email');

    final avatar = await CacheHelper.getData(key: 'avatarUrl') ??
        await CacheHelper.getData(key: 'avatar');

    final id = await CacheHelper.getData(key: 'userId') ??
        await CacheHelper.getData(key: 'id');

    if (name != null && name.toString().trim().isNotEmpty) {
      // Build a minimal UserModel with what we have
      return UserModel.fromJson({
        'id': (id is int) ? id : int.tryParse('${id ?? 0}') ?? 0,
        'nomComplet': name.toString(),
        'email': email?.toString(),
        'avatarUrl': avatar?.toString(),
      });
    }

    // Nothing found -> AppBar will show "Utilisateur"
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final routeNow = ModalRoute.of(context)?.settings.name ?? AppRoutes.voituresAdd;

    final sections = AppMenu.buildDefaultSections(

      hasPaiementAlerts: () => true,
    );

    void _navigate(String route) {
      final s = Scaffold.maybeOf(context);
      if (s?.isDrawerOpen ?? false) Navigator.of(context).pop();
      if (ModalRoute.of(context)?.settings.name == route) return;
      Navigator.of(context).pushReplacementNamed(route);
    }

    return FutureBuilder<UserModel?>(
      future: _getCurrentUser(),
      builder: (context, snap) {
        final user = snap.data; // may be null; AppBar handles fallback "Utilisateur"

        return Scaffold(
          drawer: AppSideMenu(
            activeRoute: routeNow,
            sections: sections,
            onNavigate: _navigate,
          ),
            appBar: AppBarWithMenu(
              title: 'Ajouter voiture',
              onNavigate: _navigate,
              homeRoute: AppRoutes.home,
              sections: sections,
              activeRoute: routeNow,
              currentUser: user, // ✅ will now show the real name
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          children: [
                            if (_busy) const LinearProgressIndicator(minHeight: 2),
                            Expanded(
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme.copyWith(
                                    primary: AppColors.kBg3,
                                  ),
                                ),
                                child: Stepper(
                                  type: StepperType.horizontal,
                                  currentStep: _currentStep,
                                  onStepContinue: _onContinue,
                                  onStepCancel: _onBack,
                                  controlsBuilder: (context, details) {
                                    final isLast = _currentStep == 5;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Row(
                                        children: [
                                          ElevatedButton.icon(
                                            style: _elevatedBtnStyle(),
                                            onPressed: _busy ? null : details.onStepContinue,
                                            icon: Icon(isLast ? Icons.flag : Icons.check),
                                            label: Text(isLast ? 'Terminer' : 'Continuer'),
                                          ),
                                          const SizedBox(width: 12),
                                          TextButton.icon(
                                            style: _textBtnStyle(),
                                            onPressed: _busy ? null : details.onStepCancel,
                                            icon: const Icon(Icons.arrow_back),
                                            label: const Text('Retour'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  steps: [
                                    Step(
                                      title: const Text('Voiture'),
                                      isActive: _currentStep >= 0,
                                      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                                      content: Form(key: _formVoiture, child: _buildVoitureForm()),
                                    ),
                                    Step(
                                      title: const Text('Assurance'),
                                      isActive: _currentStep >= 1,
                                      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                                      content: Form(key: _formAssurance, child: _buildAssuranceForm()),
                                    ),
                                    Step(
                                      title: const Text('Carte grise'),
                                      isActive: _currentStep >= 2,
                                      state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                                      content: Form(key: _formCarteGrise, child: _buildCarteGriseForm()),
                                    ),
                                    Step(
                                      title: const Text('Vignette'),
                                      isActive: _currentStep >= 3,
                                      state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                                      content: Form(key: _formVignette, child: _buildVignetteForm()),
                                    ),
                                    Step(
                                      title: const Text('Taxe'),
                                      isActive: _currentStep >= 4,
                                      state: _currentStep > 4 ? StepState.complete : StepState.indexed,
                                      content: Form(key: _formTaxe, child: _buildTaxeForm()),
                                    ),
                                    Step(
                                      title: const Text('Visite technique'),
                                      isActive: _currentStep >= 5,
                                      state: StepState.indexed,
                                      content: Form(key: _formVisite, child: _buildVisiteForm()),
                                    ),
                                  ],
                                ),
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
      },
    );
  }

  // ====== FORMS ======
  Widget _buildVoitureForm() {
    return LayoutBuilder(builder: (context, c) {
      final twoCols = c.maxWidth >= 720;
      Widget field(Widget w) =>
          twoCols ? SizedBox(width: (c.maxWidth - 24) / 2, child: w) : w;

      return Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          // Matricule
          field(TextFormField(
            controller: _matriculeCtrl,
            decoration: _dec('Immatriculation *', hint: 'Ex: 123TUN456'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),

          // Société
          field(
            DropdownButtonFormField<int>(
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
            ),
          ),
          if (_loadingSocietes)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(minHeight: 2),
            ),

          // Marque
          field(TextFormField(
            controller: _marqueCtrl,
            decoration: _dec('Marque *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),

          // Modèle
          field(TextFormField(
            controller: _modeleCtrl,
            decoration: _dec('Modèle *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),

          // Année
          field(TextFormField(
            controller: _anneeCtrl,
            keyboardType: TextInputType.number,
            decoration: _dec('Année *'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Obligatoire';
              final n = int.tryParse(v);
              if (n == null || n < 1980 || n > DateTime.now().year + 1)
                return 'Année invalide';
              return null;
            },
          )),

          // Numéro de châssis
          field(TextFormField(
            controller: _numeroChassisCtrl,
            decoration: _dec('Numéro de châssis *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),

          // Kilométrage
          field(TextFormField(
            controller: _kilometrageCtrl,
            keyboardType: TextInputType.number,
            decoration: _dec('Kilométrage *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),

          // Prix d'achat
          field(TextFormField(
            controller: _prixAchatCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Prix d\'achat (TND) *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),

          // Carburant
          field(DropdownButtonFormField<String>(
            value: _carburant,
            decoration: _dec('Carburant *'),
            items: const [
              DropdownMenuItem(value: 'Essence', child: Text('Essence')),
              DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
              DropdownMenuItem(value: 'Hybride', child: Text('Hybride')),
              DropdownMenuItem(value: 'Electrique', child: Text('Electrique')),
            ],
            onChanged: (v) => setState(() => _carburant = v),
            validator: (v) => v == null ? 'Obligatoire' : null,
          )),

          // Date d'achat
          field(InputDecorator(
            decoration: _dec('Date d\'achat *'),
            child: InkWell(
              onTap: () async {
                final d = await _pickDate(_dateAchat);
                if (d != null) setState(() => _dateAchat = d);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_dateAchat == null
                    ? 'Choisir une date'
                    : _dateAchat!.toIso8601String().split('T').first),
              ),
            ),
          )),

          // Numéro interne
          field(TextFormField(
            controller: _numInterneCtrl,
            decoration: _dec('Numéro interne'),
          )),

          // Occupée par


          // Switches
          SwitchListTile(
            title: const Text('Active', style: TextStyle(color: Colors.white70)),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          SwitchListTile(
            title: const Text('Saisie effectuée',
                style: TextStyle(color: Colors.white70)),
            subtitle:
            const Text('Marquer si la saisie documentaire est complète'),
            value: _saisie,
            onChanged: (v) => setState(() => _saisie = v),
          ),
        ],
      );
    });
  }

  // Small preview with fallback to '/uploads/uploads/...'
  Widget _previewImageBox(String? absUrl, {double height = 120}) {
    if (absUrl == null || absUrl.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        color: Colors.black26,
        child: const Text('Prévisualisation indisponible', style: TextStyle(color: Colors.white70)),
      );
    }

    final alt = _uploadsFallback(absUrl);

    Widget placeholder([String? msg]) => Container(
      height: height,
      alignment: Alignment.center,
      color: Colors.black26,
      child: Text(msg ?? 'Prévisualisation indisponible', style: const TextStyle(color: Colors.white70)),
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

  Widget _buildAssuranceForm() {
    return LayoutBuilder(builder: (context, c) {
      final twoCols = c.maxWidth >= 720;
      Widget field(Widget w) => twoCols ? SizedBox(width: (c.maxWidth - 24) / 2, child: w) : w;

      final isImg = _looksLikeImage(_assurancePreviewUrl);
      return Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          field(TextFormField(
            controller: _assuranceCompagnieCtrl,
            decoration: _dec('Compagnie *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(TextFormField(
            controller: _assuranceNumeroPoliceCtrl,
            decoration: _dec('Numéro de police *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(SwitchListTile(
            title: const Text('Tous risques', style: TextStyle(color: Colors.white70)),
            value: _assuranceTousRisques,
            onChanged: (v) => setState(() => _assuranceTousRisques = v),
          )),
          field(TextFormField(
            controller: _assuranceMontantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Montant (TND) *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(_dateField('Date début *', _assuranceDebut, (d) => setState(() => _assuranceDebut = d))),
          field(_dateField('Date fin *', _assuranceFin, (d) => setState(() => _assuranceFin = d))),
          field(_dateField('Date paiement *', _assuranceDatePaiement, (d) => setState(() => _assuranceDatePaiement = d))),
          field(_dateField('Prochain paiement *', _assuranceDateProchainPaiement, (d) => setState(() => _assuranceDateProchainPaiement = d))),
          field(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fichier (image/pdf) *', style: TextStyle(color: AppColors.onDark60)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                style: _outlinedBtnStyle(),
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
              if (isImg)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _previewImageBox(_assurancePreviewUrl),
                  ),
                ),
            ],
          )),
          field(TextFormField(
            controller: _assuranceNotesCtrl,
            decoration: _dec('Notes'),
            maxLines: 2,
          )),
        ],
      );
    });
  }

  Widget _buildCarteGriseForm() {
    return LayoutBuilder(builder: (context, c) {
      final twoCols = c.maxWidth >= 720;
      Widget field(Widget w) => twoCols ? SizedBox(width: (c.maxWidth - 24) / 2, child: w) : w;

      final isImg = _looksLikeImage(_cgPreviewUrl);
      return Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          field(TextFormField(
            controller: _cgNumeroCarteCtrl,
            decoration: _dec('Numéro carte grise *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(TextFormField(
            controller: _cgProprietaireCtrl,
            decoration: _dec('Propriétaire légal *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(TextFormField(
            controller: _cgMontantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Montant (TND) *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(_dateField('Date début *', _cgDateDebut, (d) => setState(() => _cgDateDebut = d))),
          field(_dateField('Date fin *', _cgDateFin, (d) => setState(() => _cgDateFin = d))),
          field(_dateField('Date paiement *', _cgDatePaiement, (d) => setState(() => _cgDatePaiement = d))),
          field(_dateField('Prochain paiement *', _cgDateProchainPaiement, (d) => setState(() => _cgDateProchainPaiement = d))),
          field(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fichier (image/pdf) *', style: TextStyle(color: AppColors.onDark60)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                style: _outlinedBtnStyle(),
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
              if (isImg)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _previewImageBox(_cgPreviewUrl),
                  ),
                ),
            ],
          )),
          field(TextFormField(
            controller: _cgNotesCtrl,
            decoration: _dec('Notes'),
            maxLines: 2,
          )),
        ],
      );
    });
  }

  Widget _buildVignetteForm() {
    return LayoutBuilder(builder: (context, c) {
      final twoCols = c.maxWidth >= 720;
      Widget field(Widget w) => twoCols ? SizedBox(width: (c.maxWidth - 24) / 2, child: w) : w;

      final isImg = _looksLikeImage(_vPreviewUrl);
      return Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          field(TextFormField(
            controller: _vAnneeFiscaleCtrl,
            keyboardType: TextInputType.number,
            decoration: _dec('Année fiscale *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(TextFormField(
            controller: _vNumeroQuitanceCtrl,
            decoration: _dec('Numéro quittance *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(TextFormField(
            controller: _vMontantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Montant (TND) *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(_dateField('Date début *', _vDateDebut, (d) => setState(() => _vDateDebut = d))),
          field(_dateField('Date fin *', _vDateFin, (d) => setState(() => _vDateFin = d))),
          field(_dateField('Date paiement *', _vDatePaiement, (d) => setState(() => _vDatePaiement = d))),
          field(_dateField('Prochain paiement *', _vDateProchainPaiement, (d) => setState(() => _vDateProchainPaiement = d))),
          field(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fichier (image/pdf) *', style: TextStyle(color: AppColors.onDark60)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                style: _outlinedBtnStyle(),
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
              if (isImg)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _previewImageBox(_vPreviewUrl),
                  ),
                ),
            ],
          )),
          field(TextFormField(
            controller: _vNotesCtrl,
            decoration: _dec('Notes'),
            maxLines: 2,
          )),
        ],
      );
    });
  }

  // NEW — formulaire Taxe
  Widget _buildTaxeForm() {
    return LayoutBuilder(builder: (context, c) {
      final twoCols = c.maxWidth >= 720;
      Widget field(Widget w) => twoCols ? SizedBox(width: (c.maxWidth - 24) / 2, child: w) : w;

      final isImg = _looksLikeImage(_tPreviewUrl);
      return Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          field(TextFormField(
            controller: _tLibelleCtrl,
            decoration: _dec('Libellé *', hint: 'Ex: Taxe municipale 2025'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(TextFormField(
            controller: _tMontantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Montant (TND) *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(_dateField('Date début *', _tDateDebut, (d) => setState(() => _tDateDebut = d))),
          field(_dateField('Date fin *', _tDateFin, (d) => setState(() => _tDateFin = d))),
          field(_dateField('Date paiement *', _tDatePaiement, (d) => setState(() => _tDatePaiement = d))),
          field(_dateField('Prochain paiement *', _tDateProchainPaiement, (d) => setState(() => _tDateProchainPaiement = d))),
          field(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fichier (image/pdf) *', style: TextStyle(color: AppColors.onDark60)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                style: _outlinedBtnStyle(),
                onPressed: () async {
                  final up = await _uploadFile(category: 'taxes');
                  if (up != null) {
                    setState(() {
                      _tFichierUrl = up.rawUrl;
                      _tPreviewUrl = up.previewUrl;
                    });
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Choisir & téléverser'),
              ),
              if (isImg)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _previewImageBox(_tPreviewUrl),
                  ),
                ),
            ],
          )),
          field(TextFormField(
            controller: _tNotesCtrl,
            decoration: _dec('Notes'),
            maxLines: 2,
          )),
        ],
      );
    });
  }

  // NEW — formulaire Visite technique
  Widget _buildVisiteForm() {
    return LayoutBuilder(builder: (context, c) {
      final twoCols = c.maxWidth >= 720;
      Widget field(Widget w) => twoCols ? SizedBox(width: (c.maxWidth - 24) / 2, child: w) : w;

      final isImg = _looksLikeImage(_vtPreviewUrl);
      return Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          field(TextFormField(
            controller: _vtCentreCtrl,
            decoration: _dec('Centre *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(TextFormField(
            controller: _vtNumeroRapportCtrl,
            decoration: _dec('Numéro de rapport *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(SwitchListTile(
            title: const Text('Contre-visite', style: TextStyle(color: Colors.white70)),
            value: _vtContreVisite,
            onChanged: (v) => setState(() => _vtContreVisite = v),
          )),
          field(TextFormField(
            controller: _vtMontantCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Montant (TND) *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          )),
          field(_dateField('Date début *', _vtDateDebut, (d) => setState(() => _vtDateDebut = d))),
          field(_dateField('Date fin *', _vtDateFin, (d) => setState(() => _vtDateFin = d))),
          field(_dateField('Date paiement *', _vtDatePaiement, (d) => setState(() => _vtDatePaiement = d))),
          field(_dateField('Prochain paiement *', _vtDateProchainPaiement, (d) => setState(() => _vtDateProchainPaiement = d))),
          field(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fichier (image/pdf) *', style: TextStyle(color: AppColors.onDark60)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                style: _outlinedBtnStyle(),
                onPressed: () async {
                  final up = await _uploadFile(category: 'visites-techniques');
                  if (up != null) {
                    setState(() {
                      _vtFichierUrl = up.rawUrl;
                      _vtPreviewUrl = up.previewUrl;
                    });
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Choisir & téléverser'),
              ),
              if (isImg)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _previewImageBox(_vtPreviewUrl),
                  ),
                ),
            ],
          )),
          field(TextFormField(
            controller: _vtNotesCtrl,
            decoration: _dec('Notes'),
            maxLines: 2,
          )),
        ],
      );
    });
  }

  // Date field helper
  Widget _dateField(String label, DateTime? current, ValueChanged<DateTime> onPick) {
    return InputDecorator(
      decoration: _dec(label),
      child: InkWell(
        onTap: () async {
          final d = await _pickDate(current);
          if (d != null) onPick(d);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(current == null ? 'Choisir' : current.toIso8601String().split('T').first),
        ),
      ),
    );
  }
}
