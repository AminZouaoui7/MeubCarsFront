// lib/Views/Voiture/CarDetails.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/core/cache/CacheHelper.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/background.dart';

class CarDetailsPage extends StatefulWidget {
  const CarDetailsPage({super.key});

  @override
  State<CarDetailsPage> createState() => _CarDetailsPageState();
}

  class _CarDetailsPageState extends State<CarDetailsPage> {
    // ===== HTTP =====
    final Dio _dio = Dio(BaseOptions(
      baseUrl: EndPoint.baseUrl, // ex: http://10.0.2.2:7178/api
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));

    // ===== Helpers URL / Preview =====
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

    String _encodePathSegments(String path) {
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
            path: _encodePathSegments(u.path.isEmpty ? '/' : u.path),
            query: u.hasQuery ? u.query : null,
          ).toString();
        } catch (_) {
          var fixed = urlOrPath;
          if (!kIsWeb && Platform.isAndroid) {
            fixed = fixed.replaceFirst(RegExp(r'^https?://(localhost|127\.0\.0\.1)'), 'http://10.0.2.2');
            fixed = fixed.replaceFirst(RegExp(r'^https://10\.0\.2\.2'), 'http://10.0.2.2');
          }
          final i = fixed.indexOf('://');
          if (i > -1) {
            final s = fixed.indexOf('/', i + 3);
            if (s > -1) {
              final base = fixed.substring(0, s);
              final rest = fixed.substring(s);
              return '$base${_encodePathSegments(rest)}';
            }
          }
          return fixed;
        }
      }

      final origin = _apiOrigin();
      String p = urlOrPath.isEmpty ? urlOrPath : (urlOrPath.startsWith('/') ? urlOrPath : '/$urlOrPath');
      p = p.replaceAll(RegExp(r'/{2,}'), '/');
      return '$origin${_encodePathSegments(p)}';
    }

    String _uploadsFallback(String absUrl) {
      final i = absUrl.indexOf('://');
      if (i < 0) return absUrl;
      final hostEnd = absUrl.indexOf('/', i + 3);
      if (hostEnd < 0) return absUrl;
      final host = absUrl.substring(0, hostEnd);
      final path = absUrl.substring(hostEnd);

      if (RegExp(r'^/uploads/(?!uploads/)', caseSensitive: false).hasMatch(path)) {
        return '$host' + path.replaceFirst(RegExp(r'^/uploads/', caseSensitive: false), '/uploads/uploads/');
      }
      return absUrl;
    }

    bool _looksLikeImage(String? url) {
      final s = (url ?? '').toLowerCase();
      return s.endsWith('.png') ||
          s.endsWith('.jpg') ||
          s.endsWith('.jpeg') ||
          s.contains('.png?') ||
          s.contains('.jpg?') ||
          s.contains('.jpeg?');
    }

    // ===== State =====
    int? _id;
    bool _loading = true;
    String? _error;
    String? _userName;


    Map<String, dynamic>? _car; // Voiture
    List<Map<String, dynamic>> _assurances = [];
    List<Map<String, dynamic>> _cartes = [];
    List<Map<String, dynamic>> _vignettes = [];
    List<Map<String, dynamic>> _visites = [];
    List<Map<String, dynamic>> _taxes = []; // NEW
    String? _societeName;


    @override
    void initState() {
      super.initState();
      _loadUserName(); // ✅ charge le nom utilisateur
    }

    Future<void> _loadUserName() async {
      final name = CacheHelper.getData<String>(key: 'userName');
      setState(() {
        _userName = (name != null && name.trim().isNotEmpty) ? name.trim() : 'Utilisateur';
      });
    }

    @override
    void didChangeDependencies() {
      super.didChangeDependencies();
      if (_id == null) {
        _id = ModalRoute.of(context)?.settings.arguments as int?;
        if (_id == null) {
          setState(() {
            _error = 'Identifiant de voiture manquant.';
            _loading = false;
          });
        } else {
          _load();
        }
      }
    }


    Future<Map<String, String>> _authHeaders() async {
      final token = await CacheHelper.getData(key: 'token');
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null && token.toString().isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      return headers;
    }

    void _toast(String s) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    }

    // ==== Helpers société ====
    String? _extractSocieteNameLocal(Map<String, dynamic> car) {
      final candidates = [
        car['societeRef'],
        car['societe'],
        car['societeNavigation'],
        car['company'],
        car['entreprise'],
      ];
      for (final c in candidates) {
        if (c is Map) {
          final m = c.cast<String, dynamic>();
          final n = (m['nom'] ?? m['name'] ?? m['libelle'] ?? m['designation'])?.toString();
          if (n != null && n.trim().isNotEmpty) return n.trim();
        } else if (c is String && c.trim().isNotEmpty) {
          return c.trim();
        }
      }
      final n = (car['societeNom'] ?? car['companyName'] ?? car['nomSociete'])?.toString();
      if (n != null && n.trim().isNotEmpty) return n.trim();
      return null;
    }

    int? _extractSocieteId(Map<String, dynamic> car) {
      final keys = ['societeId', 'SocieteId', 'companyId', 'entrepriseId'];
      for (final k in keys) {
        final v = car[k];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final p = int.tryParse(v);
          if (p != null) return p;
        }
      }
      final nested = [car['societeRef'], car['societe'], car['societeNavigation']];
      for (final n in nested) {
        if (n is Map) {
          final m = n.cast<String, dynamic>();
          final v = m['id'] ?? m['Id'];
          if (v is int) return v;
          if (v is num) return v.toInt();
          if (v is String) {
            final p = int.tryParse(v);
            if (p != null) return p;
          }
        }
      }
      return null;
    }
    // ====== Tri / Dates ======
    DateTime _parseAnyDate(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is int || v is num) {
        var ms = (v as num).toInt();
        if (ms < 1000000000000) ms *= 1000; // secondes -> ms
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
      if (v is String) {
        final s = v.trim();
        final mUnix = RegExp(r'\/Date\((\d+)\)\/').firstMatch(s);
        if (mUnix != null) {
          final ms = int.tryParse(mUnix.group(1) ?? '') ?? 0;
          return DateTime.fromMillisecondsSinceEpoch(ms);
        }
        final mDMY = RegExp(r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$').firstMatch(s);
        if (mDMY != null) {
          final d = int.parse(mDMY.group(1)!);
          final m = int.parse(mDMY.group(2)!);
          final y = int.parse(mDMY.group(3)!);
          return DateTime(y < 100 ? 2000 + y : y, m, d);
        }
        return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    DateTime _latestDate(Map<String, dynamic> m) {
      const keys = [
        'updatedAt','UpdatedAt','createdAt','CreatedAt','dateCreation','DateCreation',
        'dateFin','DateFin','dateProchainPaiement','DateProchainPaiement',
        'datePaiement','DatePaiement','dateDebut','DateDebut','date','Date',
      ];
      DateTime best = DateTime.fromMillisecondsSinceEpoch(0);
      for (final k in keys) {
        final d = _parseAnyDate(m[k]);
        if (d.isAfter(best)) best = d;
      }
      return best;
    }

    int _intId(Map<String, dynamic> m) {
      final v = m['id'] ?? m['Id'] ?? m['ID'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    int _cmpNewestFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
      final c = _latestDate(b).compareTo(_latestDate(a)); // desc
      if (c != 0) return c;
      return _intId(b).compareTo(_intId(a));
    }


    // ===== Chargement =====
    Future<void> _load() async {
      setState(() {
        _loading = true;
        _error = null;
      });

      try {
        final headers = await _authHeaders();
        final id = _id;
        if (id == null) throw Exception('Voiture ID manquant.');

        // 🔹 Appels vers les routes "actives" uniquement
        final results = await Future.wait([
          _dio.get('Voitures/$id', options: Options(headers: headers)),
          _dio.get('Assurances/by-voiture/$id/actives', options: Options(headers: headers)),
          _dio.get('CartesGrises/by-voiture/$id/actives', options: Options(headers: headers)),
          _dio.get('Vignettes/by-voiture/$id/actives', options: Options(headers: headers)),
          _dio.get('VisitesTechniques/by-voiture/$id/actives', options: Options(headers: headers)),
          _dio.get('Taxes/by-voiture/$id/actives', options: Options(headers: headers)),
        ]);

        // 🔹 Voiture principale
        final carRes = results[0];
        if (carRes.statusCode != 200) {
          throw Exception('Erreur serveur voiture (${carRes.statusCode})');
        }

        final carJson = (carRes.data as Map).cast<String, dynamic>();

        // 🔹 Nom de la société
        String? socName = _extractSocieteNameLocal(carJson);
        if (socName == null || socName.isEmpty) {
          final sid = _extractSocieteId(carJson);
          if (sid != null) {
            try {
              final sres = await _dio.get('Societes/$sid', options: Options(headers: headers));
              final sm = (sres.data as Map).cast<String, dynamic>();
              socName = (sm['nom'] ?? sm['name'] ?? sm['libelle'] ?? '').toString();
            } catch (_) {/* ignore */}
          }
        }

        // 🔹 Convertisseurs
        List<Map<String, dynamic>> _toList(dynamic v) =>
            ((v as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();

        // 🔹 Données reçues
        final assurancesQ = _toList(results[1].data);
        final cartesQ = _toList(results[2].data);
        final vignettesQ = _toList(results[3].data);
        final visitesQ = _toList(results[4].data);
        final taxesQ = _toList(results[5].data);

        // 🔹 Tri récents d’abord
        assurancesQ.sort(_cmpNewestFirst);
        cartesQ.sort(_cmpNewestFirst);
        vignettesQ.sort(_cmpNewestFirst);
        visitesQ.sort(_cmpNewestFirst);
        taxesQ.sort(_cmpNewestFirst);

        setState(() {
          _car = carJson;
          _societeName = (socName ?? '').trim();
          _assurances = assurancesQ;
          _cartes = cartesQ;
          _vignettes = vignettesQ;
          _visites = visitesQ;
          _taxes = taxesQ;
          _loading = false;
        });
      } on DioException catch (e) {
        setState(() {
          _error = e.response?.data?.toString() ?? e.message ?? 'Erreur réseau';
          _loading = false;
        });
      } catch (e) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }

    String _s(dynamic v) => (v ?? '').toString();
    String _d(dynamic iso) {
      final s = _s(iso);
      return s.isEmpty ? '—' : s.split('T').first;
    }

    // ------------------- UI small utils (dialog) -------------------

    InputDecoration _dec(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFF1A1A1E),
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2A2A2E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE4631D), width: 1.4),
      ),
    );

    Future<DateTime?> _pickDate(DateTime? current) async {
      final now = DateTime.now();
      return await showDatePicker(
        context: context,
        initialDate: current ?? now,
        firstDate: DateTime(1990),
        lastDate: DateTime(now.year + 5),
      );
    }

    Future<({String rawUrl, String previewUrl})?> _uploadFile({required String category}) async {
      try {
        final picked = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          withData: true,
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
        );
        if (picked == null || picked.files.isEmpty) return null;

        final f = picked.files.single;

        final ext = (f.extension ?? '').toLowerCase();
        final mime = ext == 'pdf'
            ? 'application/pdf'
            : (ext == 'jpg' || ext == 'jpeg')
            ? 'image/jpeg'
            : 'image/png';

        MultipartFile filePart;
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
          _toast('Fichier invalide');
          return null;
        }

        final form = FormData.fromMap({'file': filePart, 'category': category});
        final headers = await _authHeaders();
        final res = await _dio.post('Uploads', data: form, options: Options(headers: headers));
        final m = (res.data is Map) ? (res.data as Map).cast<String, dynamic>() : <String, dynamic>{};
        final raw = (m['url'] ?? m['path'] ?? m['fileUrl'] ?? '').toString();
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
    // ------------------- DIALOGS: CREATE ITEMS -------------------
    Future<void> _showAddAssuranceDialog() async {
      if (_id == null) return;
      final formKey = GlobalKey<FormState>();
      final compagnie = TextEditingController();
      final numeroPolice = TextEditingController();
      final montant = TextEditingController();
      final notes = TextEditingController();
      bool tousRisques = false;
      DateTime? dDebut, dFin, dPay, dNext;
      String? fichierUrl;
      String? previewUrl;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
          Widget dateField(String label, DateTime? val, ValueChanged<DateTime> onPick, {bool required = false}) {
            return InputDecorator(
              decoration: _dec(label),
              child: InkWell(
                onTap: () async { final d = await _pickDate(val); if (d != null) setS(() => onPick(d)); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(val == null ? (required ? 'Choisir (obligatoire)' : 'Choisir') : val.toIso8601String().split('T').first),
                ),
              ),
            );
          }

          return AlertDialog(
            title: const Text('Nouvelle assurance'),
            content: SizedBox(
              width: 600,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(controller: compagnie, decoration: _dec('Compagnie *'), validator: (v)=> (v==null||v.trim().isEmpty)?'Obligatoire':null),
                      const SizedBox(height: 10),
                      TextFormField(controller: numeroPolice, decoration: _dec('Numéro de police *'), validator: (v)=> (v==null||v.trim().isEmpty)?'Obligatoire':null),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        title: const Text('Tous risques', style: TextStyle(color: Colors.white70)),
                        value: tousRisques, onChanged: (v)=> setS(()=> tousRisques = v),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(controller: montant, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _dec('Montant (TND) *'), validator: (v)=> (v==null||v.trim().isEmpty)?'Obligatoire':null),
                      const SizedBox(height: 10),
                      dateField('Date début *', dDebut, (d)=> dDebut = d, required: true),
                      const SizedBox(height: 10),
                      dateField('Date fin *', dFin, (d)=> dFin = d, required: true),
                      const SizedBox(height: 10),
                      dateField('Date paiement *', dPay, (d)=> dPay = d, required: true),
                      const SizedBox(height: 10),
                      dateField('Prochain paiement *', dNext, (d)=> dNext = d, required: true),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Fichier (image/pdf) *', style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () async { final up = await _uploadFile(category: 'assurances'); if (up != null) setS(()=> {fichierUrl = up.rawUrl, previewUrl = up.previewUrl}); },
                              icon: const Icon(Icons.upload_file), label: const Text('Choisir & téléverser'),
                            ),
                            if ((previewUrl ?? '').isNotEmpty) const Padding(
                              padding: EdgeInsets.only(top: 8.0), child: Text('Fichier prêt', style: TextStyle(color: Colors.white60)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(controller: notes, decoration: _dec('Notes'), maxLines: 3),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: ()=> Navigator.of(ctx).pop(), child: const Text('Annuler')),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate() || dDebut==null || dFin==null || dPay==null || dNext==null || (fichierUrl??'').isEmpty) {
                    _toast('Complète tous les champs requis.'); return;
                  }
                  try {
                    final payload = {
                      'voitureId': _id,
                      'compagnie': compagnie.text.trim(),
                      'numeroPolice': numeroPolice.text.trim(),
                      'tousRisques': tousRisques,
                      'dateDebut': dDebut!.toIso8601String(),
                      'dateFin': dFin!.toIso8601String(),
                      'montant': double.tryParse(montant.text.trim()),
                      'datePaiement': dPay!.toIso8601String(),
                      'dateProchainPaiement': dNext!.toIso8601String(),
                      'fichierUrl': fichierUrl,
                      'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                      'principale': true,
                    };
                    final headers = await _authHeaders();
                    await _dio.post('Assurances', data: payload, options: Options(headers: headers));
                    if (mounted) Navigator.of(ctx).pop();
                    _toast('Assurance ajoutée'); _load();
                  } on DioException catch (e) { _toast(e.response?.data?.toString() ?? e.message ?? 'Erreur réseau'); }
                  catch (e) { _toast(e.toString()); }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        }),
      );
    }

    Future<void> _showAddCarteDialog() async {
      if (_id == null) return;
      final formKey = GlobalKey<FormState>();
      final numeroCarte = TextEditingController();
      final proprietaire = TextEditingController();
      final montant = TextEditingController();
      final notes = TextEditingController();
      DateTime? dDebut, dFin, dPay, dNext;
      String? fichierUrl; String? previewUrl;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
          Widget dateField(String label, DateTime? val, ValueChanged<DateTime> onPick, {bool required = false}) {
            return InputDecorator(
              decoration: _dec(label),
              child: InkWell(
                onTap: () async { final d = await _pickDate(val); if (d != null) setS(() => onPick(d)); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(val == null ? (required ? 'Choisir (obligatoire)' : 'Choisir') : val.toIso8601String().split('T').first),
                ),
              ),
            );
          }

          return AlertDialog(
            title: const Text('Nouvelle carte grise'),
            content: SizedBox(
              width: 600,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(controller: numeroCarte, decoration: _dec('Numéro carte grise *'), validator: (v)=> (v==null||v.trim().isEmpty)?'Obligatoire':null),
                      const SizedBox(height: 10),
                      TextFormField(controller: proprietaire, decoration: _dec('Propriétaire légal *'), validator: (v)=> (v==null||v.trim().isEmpty)?'Obligatoire':null),
                      const SizedBox(height: 10),
                      TextFormField(controller: montant, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _dec('Montant (TND) *'), validator: (v)=> (v==null||v.trim().isEmpty)?'Obligatoire':null),
                      const SizedBox(height: 10),
                      dateField('Date début *', dDebut, (d)=> dDebut = d, required: true),
                      const SizedBox(height: 10),
                      dateField('Date fin *', dFin, (d)=> dFin = d, required: true),
                      const SizedBox(height: 10),
                      dateField('Date paiement *', dPay, (d)=> dPay = d, required: true),
                      const SizedBox(height: 10),
                      dateField('Prochain paiement *', dNext, (d)=> dNext = d, required: true),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Fichier (image/pdf) *', style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () async { final up = await _uploadFile(category: 'cartes-grises'); if (up != null) setS(()=> {fichierUrl = up.rawUrl, previewUrl = up.previewUrl}); },
                              icon: const Icon(Icons.upload_file), label: const Text('Choisir & téléverser'),
                            ),
                            if ((previewUrl ?? '').isNotEmpty) const Padding(
                              padding: EdgeInsets.only(top: 8.0), child: Text('Fichier prêt', style: TextStyle(color: Colors.white60)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(controller: notes, decoration: _dec('Notes'), maxLines: 3),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: ()=> Navigator.of(ctx).pop(), child: const Text('Annuler')),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate() || dDebut==null || dFin==null || dPay==null || dNext==null || (fichierUrl??'').isEmpty) {
                    _toast('Complète tous les champs requis.'); return;
                  }
                  try {
                    final payload = {
                      'voitureId': _id,
                      'numeroCarte': numeroCarte.text.trim(),
                      'proprietaireLegal': proprietaire.text.trim(),
                      'dateDebut': dDebut!.toIso8601String(),
                      'dateFin': dFin!.toIso8601String(),
                      'montant': double.tryParse(montant.text.trim()),
                      'datePaiement': dPay!.toIso8601String(),
                      'dateProchainPaiement': dNext!.toIso8601String(),
                      'fichierUrl': fichierUrl,
                      'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                      'principale': true,
                    };
                    final headers = await _authHeaders();
                    await _dio.post('CartesGrises', data: payload, options: Options(headers: headers));
                    if (mounted) Navigator.of(ctx).pop();
                    _toast('Carte grise ajoutée'); _load();
                  } on DioException catch (e) { _toast(e.response?.data?.toString() ?? e.message ?? 'Erreur réseau'); }
                  catch (e) { _toast(e.toString()); }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        }),
      );
    }

    Future<void> _showAddVignetteDialog() async {
      if (_id == null) return;
      final formKey = GlobalKey<FormState>();
      final annee = TextEditingController();
      final quittance = TextEditingController();
      final montant = TextEditingController();
      final notes = TextEditingController();
      DateTime? dDebut, dFin, dPay, dNext;
      String? fichierUrl;
      String? previewUrl;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
          Widget dateField(
              String label,
              DateTime? val,
              ValueChanged<DateTime> onPick, {
                bool required = false,
              }) {
            return InputDecorator(
              decoration: _dec(label),
              child: InkWell(
                onTap: () async {
                  final d = await _pickDate(val);
                  if (d != null) setS(() => onPick(d));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    val == null
                        ? (required ? 'Choisir (obligatoire)' : 'Choisir')
                        : val.toIso8601String().split('T').first,
                  ),
                ),
              ),
            );
          }

          return AlertDialog(
            title: const Text('Nouvelle vignette'),
            content: SizedBox(
              width: 600,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: annee,
                        keyboardType: TextInputType.number,
                        decoration: _dec('Année fiscale *'),
                        validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: quittance,
                        decoration: _dec('Numéro quittance *'),
                        validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: montant,
                        keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                        decoration: _dec('Montant (TND) *'),
                        validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                      ),
                      const SizedBox(height: 10),
                      dateField('Date début *', dDebut, (d) => dDebut = d,
                          required: true),
                      const SizedBox(height: 10),
                      dateField('Date fin *', dFin, (d) => dFin = d, required: true),
                      const SizedBox(height: 10),
                      dateField('Date paiement *', dPay, (d) => dPay = d,
                          required: true),
                      const SizedBox(height: 10),
                      dateField('Prochain paiement *', dNext, (d) => dNext = d,
                          required: true),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Fichier (image/pdf) *',
                                style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final up =
                                await _uploadFile(category: 'vignettes');
                                if (up != null) {
                                  setS(() {
                                    fichierUrl = up.rawUrl;
                                    previewUrl = up.previewUrl;
                                  });
                                }
                              },
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Choisir & téléverser'),
                            ),
                            if ((previewUrl ?? '').isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text('Fichier prêt',
                                    style: TextStyle(color: Colors.white60)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: notes,
                        decoration: _dec('Notes'),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate() ||
                      dDebut == null ||
                      dFin == null ||
                      dPay == null ||
                      dNext == null ||
                      (fichierUrl ?? '').isEmpty) {
                    _toast('Complète tous les champs requis.');
                    return;
                  }
                  try {
                    final payload = {
                      'voitureId': _id,
                      'anneeFiscale': int.tryParse(annee.text.trim()),
                      'numeroQuittance': quittance.text.trim(), // ✅ corrigé ici
                      'dateDebut': dDebut!.toIso8601String(),
                      'dateFin': dFin!.toIso8601String(),
                      'montant': double.tryParse(montant.text.trim()),
                      'datePaiement': dPay!.toIso8601String(),
                      'dateProchainPaiement': dNext!.toIso8601String(),
                      'fichierUrl': fichierUrl,
                      'notes':
                      notes.text.trim().isEmpty ? null : notes.text.trim(),
                      'principale': true,
                    };
                    final headers = await _authHeaders();
                    await _dio.post('Vignettes',
                        data: payload, options: Options(headers: headers));
                    if (mounted) Navigator.of(ctx).pop();
                    _toast('Vignette ajoutée');
                    _load();
                  } on DioException catch (e) {
                    _toast(e.response?.data?.toString() ??
                        e.message ??
                        'Erreur réseau');
                  } catch (e) {
                    _toast(e.toString());
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        }),
      );
    }

    Future<void> _showAddVisiteDialog() async {
      if (_id == null) return;
      final formKey = GlobalKey<FormState>();
      final centre = TextEditingController();
      final numeroRapport = TextEditingController();
      final libelle = TextEditingController();
      final montant = TextEditingController();
      final notes = TextEditingController();
      bool contreVisite = false;
      DateTime? dDebut, dFin, dPay, dNext;
      String? fichierUrl; String? previewUrl;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
          Widget dateField(String label, DateTime? val, ValueChanged<DateTime> onPick, {bool required = false}) {
            return InputDecorator(
              decoration: _dec(label),
              child: InkWell(
                onTap: () async { final d = await _pickDate(val); if (d != null) setS(() => onPick(d)); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(val == null ? (required ? 'Choisir (obligatoire)' : 'Choisir') : val.toIso8601String().split('T').first),
                ),
              ),
            );
          }

          return AlertDialog(
            title: const Text('Nouvelle visite technique'),
            content: SizedBox(
              width: 600,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(controller: centre, decoration: _dec('Centre *'), validator: (v)=> (v==null||v.trim().isEmpty)?'Obligatoire':null),
                      const SizedBox(height: 10),
                      TextFormField(controller: numeroRapport, decoration: _dec('Numéro de rapport *'), validator: (v)=> (v==null||v.trim().isEmpty)?'Obligatoire':null),
                      const SizedBox(height: 10),
                      TextFormField(controller: libelle, decoration: _dec('Libellé')),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        title: const Text('Contre-visite', style: TextStyle(color: Colors.white70)),
                        value: contreVisite, onChanged: (v)=> setS(()=> contreVisite = v),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(controller: montant, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _dec('Montant (TND) *'), validator: (v)=> (v==null||v.trim().isEmpty)?'Obligatoire':null),
                      const SizedBox(height: 10),
                      dateField('Date début *', dDebut, (d)=> dDebut = d, required: true),
                      const SizedBox(height: 10),
                      dateField('Date fin *', dFin, (d)=> dFin = d, required: true),
                      const SizedBox(height: 10),
                      dateField('Date paiement *', dPay, (d)=> dPay = d, required: true),
                      const SizedBox(height: 10),
                      dateField('Prochain paiement *', dNext, (d)=> dNext = d, required: true),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Fichier (image/pdf) *', style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () async { final up = await _uploadFile(category: 'visites-techniques'); if (up != null) setS(()=> {fichierUrl = up.rawUrl, previewUrl = up.previewUrl}); },
                              icon: const Icon(Icons.upload_file), label: const Text('Choisir & téléverser'),
                            ),
                            if ((previewUrl ?? '').isNotEmpty) const Padding(
                              padding: EdgeInsets.only(top: 8.0), child: Text('Fichier prêt', style: TextStyle(color: Colors.white60)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(controller: notes, decoration: _dec('Notes'), maxLines: 3),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: ()=> Navigator.of(ctx).pop(), child: const Text('Annuler')),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate() || dDebut==null || dFin==null || dPay==null || dNext==null || (fichierUrl??'').isEmpty) {
                    _toast('Complète tous les champs requis.'); return;
                  }
                  try {
                    final payload = {
                      'voitureId': _id,
                      'libelle': libelle.text.trim().isEmpty ? null : libelle.text.trim(),
                      'centre': centre.text.trim(),
                      'numeroRapport': numeroRapport.text.trim(),
                      'contreVisite': contreVisite,
                      'dateDebut': dDebut!.toIso8601String(),
                      'dateFin': dFin!.toIso8601String(),
                      'montant': double.tryParse(montant.text.trim()),
                      'datePaiement': dPay!.toIso8601String(),
                      'dateProchainPaiement': dNext!.toIso8601String(),
                      'fichierUrl': fichierUrl,
                      'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                      'principale': true,
                    };
                    final headers = await _authHeaders();
                    await _dio.post('VisitesTechniques', data: payload, options: Options(headers: headers));
                    if (mounted) Navigator.of(ctx).pop();
                    _toast('Visite technique ajoutée'); _load();
                  } on DioException catch (e) { _toast(e.response?.data?.toString() ?? e.message ?? 'Erreur réseau'); }
                  catch (e) { _toast(e.toString()); }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        }),
      );
    }

    // NEW — Dialog ajout Taxe
    Future<void> _showAddTaxeDialog() async {
      if (_id == null) return;
      final formKey = GlobalKey<FormState>();
      final libelle = TextEditingController();
      final quittance = TextEditingController();
      final montant = TextEditingController();
      final notes = TextEditingController();
      DateTime? dDebut, dFin, dPay, dNext;
      String? fichierUrl; String? previewUrl;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
          Widget dateField(String label, DateTime? val, ValueChanged<DateTime> onPick, {bool required = false}) {
            return InputDecorator(
              decoration: _dec(label),
              child: InkWell(
                onTap: () async { final d = await _pickDate(val); if (d != null) setS(() => onPick(d)); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(val == null ? (required ? 'Choisir (obligatoire)' : 'Choisir') : val.toIso8601String().split('T').first),
                ),
              ),
            );
          }

          return AlertDialog(
            title: const Text('Nouvelle taxe'),
            content: SizedBox(
              width: 600,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(controller: libelle, decoration: _dec('Libellé *'), validator: (v)=> (v==null||v.trim().isEmpty)?'Obligatoire':null),
                      const SizedBox(height: 10),
                      TextFormField(controller: quittance, decoration: _dec('Numéro quittance *'), validator: (v)=> (v==null||v.trim().isEmpty)?'Obligatoire':null),
                      const SizedBox(height: 10),
                      TextFormField(controller: montant, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _dec('Montant (TND) *'), validator: (v)=> (v==null||v.trim().isEmpty)?'Obligatoire':null),
                      const SizedBox(height: 10),
                      dateField('Date début *', dDebut, (d)=> dDebut = d, required: true),
                      const SizedBox(height: 10),
                      dateField('Date fin *', dFin, (d)=> dFin = d, required: true),
                      const SizedBox(height: 10),
                      dateField('Date paiement *', dPay, (d)=> dPay = d, required: true),
                      const SizedBox(height: 10),
                      dateField('Prochain paiement *', dNext, (d)=> dNext = d, required: true),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Fichier (image/pdf) *', style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () async { final up = await _uploadFile(category: 'taxes'); if (up != null) setS(()=> {fichierUrl = up.rawUrl, previewUrl = up.previewUrl}); },
                              icon: const Icon(Icons.upload_file), label: const Text('Choisir & téléverser'),
                            ),
                            if ((previewUrl ?? '').isNotEmpty) const Padding(
                              padding: EdgeInsets.only(top: 8.0), child: Text('Fichier prêt', style: TextStyle(color: Colors.white60)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(controller: notes, decoration: _dec('Notes'), maxLines: 3),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: ()=> Navigator.of(ctx).pop(), child: const Text('Annuler')),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate() || dDebut==null || dFin==null || dPay==null || dNext==null || (fichierUrl??'').isEmpty) {
                    _toast('Complète tous les champs requis.'); return;
                  }
                  try {
                    final payload = {
                      'voitureId': _id,
                      'libelle': libelle.text.trim(),
                      'numeroQuittance': quittance.text.trim(),
                      'dateDebut': dDebut!.toIso8601String(),
                      'dateFin': dFin!.toIso8601String(),
                      'montant': double.tryParse(montant.text.trim()),
                      'datePaiement': dPay!.toIso8601String(),
                      'dateProchainPaiement': dNext!.toIso8601String(),
                      'fichierUrl': fichierUrl,
                      'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                      'principale': true,
                    };
                    final headers = await _authHeaders();
                    await _dio.post('Taxes', data: payload, options: Options(headers: headers));
                    if (mounted) Navigator.of(ctx).pop();
                    _toast('Taxe ajoutée'); _load();
                  } on DioException catch (e) { _toast(e.response?.data?.toString() ?? e.message ?? 'Erreur réseau'); }
                  catch (e) { _toast(e.toString()); }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        }),
      );
    }
    // ===== UI =====
    @override
    Widget build(BuildContext context) {
      final routeNow = AppRoutes.voituresList;

      final sections = AppMenu.buildDefaultSections(
      );

      Widget body;
      if (_loading) {
        body = const Center(child: CircularProgressIndicator());
      } else if (_error != null) {
        body = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        );
      } else {
        body = _DetailsView(
          car: _car!,
          societeName: _societeName,
          assurances: _assurances,
          cartes: _cartes,
          vignettes: _vignettes,
          visites: _visites,
          taxes: _taxes, // ✅
          toAbsolute: _absoluteFrom,
          uploadsFallback: _uploadsFallback,
          looksLikeImage: _looksLikeImage,
          onEdit: () {
            if (_id != null) {
              Navigator.of(context).pushNamed(
                AppRoutes.voituresEdit,
                arguments: _id,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ID de la voiture manquant')),
              );
            }
          },
          onAddAssurance: _showAddAssuranceDialog,
          onAddCarte: _showAddCarteDialog,
          onAddVignette: _showAddVignetteDialog,
          onAddVisite: _showAddVisiteDialog,
          onAddTaxe: _showAddTaxeDialog,
        );
      }

      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBarWithMenu(
          title: 'Détails voiture',
          userName: _userName, // ✅ ajouté ici
          onNavigate: (r) => Navigator.of(context).pushReplacementNamed(r),
          sections: sections,
          activeRoute: routeNow,
        ),
        drawer: AppBarWithMenu(
          title: 'Détails voiture',
          userName: _userName, // ✅ déjà correct ici
          onNavigate: (r) => Navigator.of(context).pushReplacementNamed(r),
          sections: sections,
          activeRoute: routeNow,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const BrandBackground(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      color: const Color(0xFF121214).withOpacity(.55),
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.kBg3),
                      ),
                      child: body,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

/// =============================
/// Details + FILTRES PAR DATES
/// =============================

// ---- Déclarations au NIVEAU FICHIER (pour éviter l’erreur des enums) ----
enum _PayKind { paid, overdue, dueToday, dueSoon, ok, unknown }

class _StatusInfo {
  final String label;
  final _PayKind kind;
  const _StatusInfo(this.label, this.kind);
}

class _StatusStyle {
  final Color bg;
  final Color fg;
  final IconData icon;
  final Color accent;
  const _StatusStyle({
    required this.bg,
    required this.fg,
    required this.icon,
    required this.accent,
  });
}

class _StatusBadge {
  final Widget pill;
  final Color accent;
  const _StatusBadge(this.pill, this.accent);
}

class _DetailsView extends StatefulWidget {
  final Map<String, dynamic> car;
  final String? societeName;
  final List<Map<String, dynamic>> assurances;
  final List<Map<String, dynamic>> cartes;
  final List<Map<String, dynamic>> vignettes;
  final List<Map<String, dynamic>> visites;
  final List<Map<String, dynamic>> taxes; // NEW
  final String Function(String url) toAbsolute;
  final String Function(String absUrl) uploadsFallback;
  final bool Function(String? url) looksLikeImage;
  final VoidCallback? onEdit;

  final VoidCallback? onAddAssurance;
  final VoidCallback? onAddCarte;
  final VoidCallback? onAddVignette;
  final VoidCallback? onAddVisite;
  final VoidCallback? onAddTaxe; // NEW

  const _DetailsView({
    required this.car,
    required this.assurances,
    required this.cartes,
    required this.vignettes,
    required this.visites,
    required this.taxes,
    required this.toAbsolute,
    required this.uploadsFallback,
    required this.looksLikeImage,
    this.societeName,
    this.onEdit,
    this.onAddAssurance,
    this.onAddCarte,
    this.onAddVignette,
    this.onAddVisite,
    this.onAddTaxe,
  });

  @override
  State<_DetailsView> createState() => _DetailsViewState();
}

class _DetailsViewState extends State<_DetailsView> {
  String _s(dynamic v) => (v ?? '').toString();
  String _d(dynamic iso) {
    final s = _s(iso);
    return s.isEmpty ? '—' : s.split('T').first;
  }

  bool _b(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes' || s == 'y' || s == 'oui';
  }

  bool _isPrincipal(Map<String, dynamic> m) =>
      m['principale'] == true ||
          m['isPrincipale'] == true ||
          m['principal'] == true ||
          m['__uiPrincipale'] == true;

  String _fmt(DateTime? d) =>
      d == null ? '—' : d.toIso8601String().split('T').first;

  // ================= STATUT PAIEMENT =======================
  _StatusInfo _paymentStatusInfo(Map<String, dynamic> m) {
    final s =
    _s(m['statutPaiement'] ?? m['statusPaiement'] ?? m['statut'] ?? m['status']);
    if (s.isNotEmpty) {
      final l = s.toLowerCase();
      if (l.contains('pay')) return _StatusInfo('Payé', _PayKind.paid);
      if (l.contains('retard') || l.contains('overdue') || l.contains('late')) {
        return _StatusInfo('En retard', _PayKind.overdue);
      }
    }
    final paidFlag = m['paid'] == true ||
        m['isPaid'] == true ||
        m['paye'] == true ||
        m['regle'] == true ||
        m['settled'] == true;
    if (paidFlag) return _StatusInfo('Payé', _PayKind.paid);

    final due = DateTime.tryParse(_s(m['dateProchainPaiement'] ?? m['dateFin'])) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    if (due.millisecondsSinceEpoch == 0) {
      return _StatusInfo('—', _PayKind.unknown);
    }

    final diff = due.difference(DateTime.now()).inDays;
    if (diff < 0)
      return _StatusInfo('En retard (échéance ${_fmt(due)})', _PayKind.overdue);
    if (diff == 0) return _StatusInfo('Échéance aujourd’hui', _PayKind.dueToday);
    if (diff <= 30)
      return _StatusInfo('À venir (dans $diff j)', _PayKind.dueSoon);
    return _StatusInfo('À jour', _PayKind.ok);
  }

  _StatusStyle _statusColors(_PayKind k) {
    Color bg = Colors.blueGrey;
    IconData icon = Icons.help_rounded;
    switch (k) {
      case _PayKind.overdue:
        bg = Colors.redAccent;
        icon = Icons.warning_amber_rounded;
        break;
      case _PayKind.dueToday:
        bg = Colors.deepOrange;
        icon = Icons.notifications_active_rounded;
        break;
      case _PayKind.dueSoon:
        bg = Colors.amber;
        icon = Icons.access_time_filled_rounded;
        break;
      case _PayKind.paid:
        bg = Colors.green;
        icon = Icons.check_circle_rounded;
        break;
      case _PayKind.ok:
        bg = Colors.teal;
        icon = Icons.verified_rounded;
        break;
      default:
        break;
    }
    final fg = bg.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
    return _StatusStyle(bg: bg, fg: fg, icon: icon, accent: bg);
  }

  _StatusBadge _statusBadge(Map<String, dynamic> m) {
    final info = _paymentStatusInfo(m);
    final c = _statusColors(info.kind);
    return _StatusBadge(
      _statusPill(info.label, c.bg, c.fg, c.icon),
      c.accent,
    );
  }

  Widget _statusPill(String text, Color bg, Color fg, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: bg.withOpacity(.18),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: bg, width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: bg),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      ],
    ),
  );

  // ===================== PRÉVISUALISATION IMAGE =======================
  Widget _filePreview(BuildContext context, String? fichierUrl) {
    if (fichierUrl == null || fichierUrl.trim().isEmpty) {
      return _previewBox(const Text('Aucun fichier'));
    }
    final abs = widget.toAbsolute(fichierUrl);
    final alt = widget.uploadsFallback(abs);
    final isImg = widget.looksLikeImage(abs) || widget.looksLikeImage(fichierUrl);

    if (isImg) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          abs,
          height: 220,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.network(
            alt,
            height: 220,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                _previewBox(const Text('Prévisualisation indisponible')),
          ),
        ),
      );
    }

    return _previewBox(
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () async {
            final uri = Uri.parse(abs);
            if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
              final uri2 = Uri.parse(alt);
              await launchUrl(uri2, mode: LaunchMode.externalApplication);
            }
          },
          icon: const Icon(Icons.open_in_new),
          label: const Text('Ouvrir le fichier'),
        ),
      ),
    );
  }

  Widget _previewBox(Widget child) => Container(
    height: 220,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A1E),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF2A2A2E)),
    ),
    child: child,
  );

  // ======================= BUILD PRINCIPAL ============================
  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    final title = '${_s(car['marque'])} ${_s(car['modele'])}';
    final societe = (widget.societeName ?? '').trim();
    final couleur = _s(car['couleur']);

    final bool isActive = _b(car['active'] ?? car['isActive']);
    final bool isSaisie = _b(car['saisie'] ?? car['isSaisie']);

    Widget _pill({
      required bool on,
      required String yes,
      required String no,
      required Color color,
      required IconData yesIcon,
      required IconData noIcon,
    }) {
      final c = on ? color : Colors.blueGrey;
      final ic = on ? yesIcon : noIcon;
      final txt = on ? yes : no;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: c.withOpacity(.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.withOpacity(.9), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ic, size: 16, color: c),
            const SizedBox(width: 6),
            Text(txt, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final activeBadge = _pill(
      on: isActive,
      yes: 'Active',
      no: 'Inactive',
      color: Colors.green,
      yesIcon: Icons.verified_rounded,
      noIcon: Icons.block,
    );

    final saisieBadge = _pill(
      on: isSaisie,
      yes: 'Saisie',
      no: 'Non saisie',
      color: Colors.orange,
      yesIcon: Icons.gavel_rounded,
      noIcon: Icons.gavel_outlined,
    );

    final chips = <Widget>[
      if (couleur.isNotEmpty) Chip(label: Text('Couleur $couleur')),
      if (_s(car['carburant']).isNotEmpty) Chip(label: Text(_s(car['carburant']))),
      if (car['annee'] != null) Chip(label: Text('Année ${car['annee']}')),
      if (car['kilometrage'] != null)
        Chip(label: Text('${car['kilometrage']} km')),
    ];

    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          // ---- En-tête voiture ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                        const Icon(Icons.directions_car_filled, size: 36),
                        title: Text(title,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        subtitle:
                        Text('Matricule: ${car['matricule'] ?? ''}'),
                      ),
                    ),
                    activeBadge,
                    saisieBadge,
                    const SizedBox(width: 12),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: -6, children: chips),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _infoTile(
                        icon: Icons.apartment,
                        title: 'Société',
                        value: societe.isEmpty ? '—' : societe,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _infoTile(
                        icon: Icons.event_available,
                        title: 'Date d\'achat',
                        value: _d(car['dateAchat']),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _infoTile(
                        icon: Icons.payments_outlined,
                        title: 'Prix d\'achat',
                        value: car['prixAchat'] == null
                            ? '—'
                            : '${car['prixAchat']} TND',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ---- Onglets ----
          TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: const Color(0xFFE4631D),
            tabs: [
              Tab(text: 'Assurances (${widget.assurances.length})'),
              Tab(text: 'Cartes grises (${widget.cartes.length})'),
              Tab(text: 'Vignettes (${widget.vignettes.length})'),
              Tab(text: 'Visites (${widget.visites.length})'),
              Tab(text: 'Taxes (${widget.taxes.length})'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _tabWithAdd(onAdd: widget.onAddAssurance, list: _tabList(widget.assurances, context)),
                _tabWithAdd(onAdd: widget.onAddCarte, list: _tabList(widget.cartes, context)),
                _tabWithAdd(onAdd: widget.onAddVignette, list: _tabList(widget.vignettes, context)),
                _tabWithAdd(onAdd: widget.onAddVisite, list: _tabList(widget.visites, context)),
                _tabWithAdd(onAdd: widget.onAddTaxe, list: _tabList(widget.taxes, context)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Retour'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Modifier'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabWithAdd({VoidCallback? onAdd, required Widget list}) => Column(
    children: [
      Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter'),
        ),
      ),
      Expanded(child: list),
    ],
  );

  Widget _infoTile(
      {required IconData icon, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2E)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                    const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === Onglets contenus ===
  Widget _tabList(List<Map<String, dynamic>> items, BuildContext context) {
    if (items.isEmpty) {
      return const Center(
          child: Text('Aucun élément', style: TextStyle(color: Colors.white70)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final m = items[i];
        final sb = _statusBadge(m);
        return _docCard(
          titleLeft: m['libelle'] ??
              m['compagnie'] ??
              m['centre'] ??
              m['type'] ??
              'Élément',
          titleRight: _s(m['numeroPolice'] ??
              m['numeroQuitance'] ??
              m['numeroRapport'] ??
              ''),
          chips: [
            Chip(label: Text('Début ${_d(m['dateDebut'])}')),
            Chip(label: Text('Fin ${_d(m['dateFin'])}')),
            if (m['montant'] != null)
              Chip(label: Text('${m['montant']} TND')),
          ],
          rows: [
            _rowWidget('Statut', sb.pill),
            _row('Paiement', _d(m['datePaiement'])),
            _row('Prochain paiement', _d(m['dateProchainPaiement'])),
            _row('Notes', _s(m['notes']).isEmpty ? '—' : _s(m['notes'])),
          ],
          preview: _filePreview(context, m['fichierUrl']),
          accent: sb.accent,
        );
      },
    );
  }

  Widget _docCard({
    required String titleLeft,
    required String titleRight,
    required List<Widget> chips,
    required List<Widget> rows,
    required Widget preview,
    Color? accent,
  }) =>
      Card(
        color: const Color(0xFF141418),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: accent ?? const Color(0xFF2A2A2E))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(titleLeft,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700))),
              Text(titleRight, style: const TextStyle(color: Colors.white70))
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: -6, children: chips),
            const SizedBox(height: 10),
            ...rows,
            const SizedBox(height: 10),
            preview,
          ]),
        ),
      );

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      SizedBox(width: 160, child: Text(k, style: const TextStyle(color: Colors.white60))),
      const Text(':  '),
      Expanded(child: Text(v, style: const TextStyle(color: Colors.white))),
    ]),
  );

  Widget _rowWidget(String k, Widget v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      SizedBox(width: 160, child: Text(k, style: const TextStyle(color: Colors.white60))),
      const Text(':  '),
      Expanded(child: Align(alignment: Alignment.centerLeft, child: v)),
    ]),
  );
}
