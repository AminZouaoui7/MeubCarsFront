// lib/Views/Voiture/Creerflux.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:meubcars/core/cache/cacheHelper.dart';
import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/background.dart';

/// Petit modèle id/label
class _IdLabel {
  final int id;
  final String label;
  const _IdLabel(this.id, this.label);
  @override
  String toString() => label;
}

class Creerflux extends StatefulWidget {
  const Creerflux({super.key});
  @override
  State<Creerflux> createState() => _CreerfluxState();
}

class _CreerfluxState extends State<Creerflux> {
  final _formKey = GlobalKey<FormState>();

  final _departCtrl      = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _objetCtrl       = TextEditingController();
  final _kmCtrl          = TextEditingController();
  final _coutCtrl        = TextEditingController();
  final _notesCtrl       = TextEditingController();

  DateTime? _date;
  TimeOfDay? _time;

  // HTTP
  final Dio _dio = Dio(BaseOptions(baseUrl: EndPoint.baseUrl));
  Future<Map<String, String>> _authHeaders() async {
    final token = await CacheHelper.getData(key: 'token');
    final h = <String, String>{'Accept': 'application/json'};
    if (token != null && token.toString().isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  // Sélections
  _IdLabel? _vehicule;   // voitureId (obligatoire)
  _IdLabel? _chauffeur;  // chauffeurId (optionnel)

  // Collections
  List<_IdLabel> _vehicules  = const [];
  List<_IdLabel> _chauffeurs = const [];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _primeWithRouteArgAndLoad());
  }

  @override
  void dispose() {
    _departCtrl.dispose();
    _destinationCtrl.dispose();
    _objetCtrl.dispose();
    _kmCtrl.dispose();
    _coutCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _primeWithRouteArgAndLoad() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    int? voitureId;
    if (args is int) {
      voitureId = args;
    } else if (args is Map && args['voitureId'] != null) {
      voitureId = int.tryParse(args['voitureId'].toString());
    }
    await _loadLists(preselectVoitureId: voitureId);
  }

  // ========= Helpers parsing & labels =========
  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  String _asString(dynamic v) => (v ?? '').toString();

  // Accepte Employe/Employee/Chauffeur/Driver/2
  bool _isChauffeur(dynamic roleField) {
    final s = _asString(roleField).trim().toLowerCase();
    final n = _asInt(roleField);
    return n == 2 ||
        s == '2' ||
        s == 'employe' ||
        s == 'employee' ||
        s == 'chauffeur' ||
        s == 'driver';
  }

  String _pickName(Map<String, dynamic> m) {
    for (final k in const [
      'nomComplet', 'NomComplet',
      'fullName', 'FullName',
      'name', 'Name',
      'username', 'Username',
      'email', 'Email',
    ]) {
      final v = m[k];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
      }
    }
    return '';
  }

  // ========= Fetch voitures =========
  Future<List<_IdLabel>> _fetchVoitures(Map<String, String> headers) async {
    final res = await _dio.get('Voitures', options: Options(headers: headers));
    final list = (res.data as List? ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .map<_IdLabel>((m) {
      final id = _asInt(m['id']) ?? 0;
      final lib = '${_asString(m['marque'])} ${_asString(m['modele'])} · ${_asString(m['matricule'])}'.trim();
      return _IdLabel(id, lib.isEmpty ? 'Voiture #$id' : lib);
    })
        .where((it) => it.id != 0)
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return list;
  }

  // ========= Fetch chauffeurs (uniquement role = 2/Employe) =========
  Future<List<_IdLabel>> _fetchChauffeurs(Map<String, String> headers) async {
    List<Map<String, dynamic>> raw = [];
    Map<String, dynamic> _asMap(dynamic e) => (e as Map).cast<String, dynamic>();

    // 1) Endpoint dédié
    try {
      final r = await _dio.get('Utilisateurs/chauffeurs', options: Options(headers: headers));
      raw = (r.data as List? ?? const []).map(_asMap).toList();
      if (kDebugMode) print('[chauffeurs] via Utilisateurs/chauffeurs -> ${raw.length}');
    } catch (_) {}

    // 2) ?role=Employe
    if (raw.isEmpty) {
      try {
        final r = await _dio.get(
          'Utilisateurs',
          queryParameters: {'role': 'Employe'},
          options: Options(headers: headers),
        );
        raw = (r.data as List? ?? const []).map(_asMap).toList();
        if (kDebugMode) print('[chauffeurs] via Utilisateurs?role=Employe -> ${raw.length}');
      } catch (_) {}
    }

    // 3) ?role=2 (numérique)
    if (raw.isEmpty) {
      try {
        final r = await _dio.get(
          'Utilisateurs',
          queryParameters: {'role': 2},
          options: Options(headers: headers),
        );
        raw = (r.data as List? ?? const []).map(_asMap).toList();
        if (kDebugMode) print('[chauffeurs] via Utilisateurs?role=2 -> ${raw.length}');
      } catch (_) {}
    }

    // 4) full list puis filtre local (au cas où l’API ignore les filtres)
    if (raw.isEmpty) {
      final r = await _dio.get('Utilisateurs', options: Options(headers: headers));
      raw = (r.data as List? ?? const []).map(_asMap).toList();
      if (kDebugMode) print('[chauffeurs] via Utilisateurs (all) -> ${raw.length}');
    }

    // 🔒 forcer le filtre local par rôle
    final filtered = raw.where((m) {
      final rf = m['role'] ?? m['Role'] ?? m['roleId'] ?? m['RoleId'];
      return _isChauffeur(rf);
    }).toList();

    final list = filtered
        .map<_IdLabel>((m) {
      final id  = _asInt(m['id']) ?? _asInt(m['Id']) ?? 0;
      final nom = _pickName(m);
      return _IdLabel(id, nom.isEmpty ? 'Chauffeur #$id' : nom);
    })
        .where((it) => it.id != 0)
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    if (kDebugMode) print('[chauffeurs] final list -> ${list.length}');
    return list;
  }

  Future<void> _loadLists({int? preselectVoitureId}) async {
    setState(() => _loading = true);
    try {
      final headers = await _authHeaders();

      final results = await Future.wait<List<_IdLabel>>([
        _fetchVoitures(headers),
        _fetchChauffeurs(headers),
      ], eagerError: true);

      final vList = results[0];
      final cList = results[1];

      setState(() {
        _vehicules  = vList;
        _chauffeurs = cList;

        if (preselectVoitureId != null) {
          _vehicule = _vehicules.firstWhere(
                (v) => v.id == preselectVoitureId,
            orElse: () => _vehicule ?? (vList.isNotEmpty ? vList.first : const _IdLabel(0, '')),
          );
          if (_vehicule?.id == 0) _vehicule = null;
        }
      });

      if (cList.isEmpty) {
        _toast('Aucun chauffeur trouvé (Utilisateurs avec rôle = 2).');
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final data = e.response?.data?.toString();
      _toast('Chargement des listes impossible. [$code] ${e.message}\n${data ?? ''}');
    } catch (e) {
      _toast('Chargement des listes impossible. $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ========= UI helpers =========
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Sélectionner une date',
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      helpText: 'Sélectionner une heure',
    );
    if (t != null) setState(() => _time = t);
  }

  DateTime? get _combinedDateTime {
    if (_date == null || _time == null) return null;
    return DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
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
    errorBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Colors.redAccent),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );

  // ========= Submit =========
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final dt = _combinedDateTime;
    if (dt == null) {
      _toast('Veuillez choisir date et heure');
      return;
    }
    if (_vehicule == null) {
      _toast('Veuillez choisir un véhicule');
      return;
    }

    final km   = _kmCtrl.text.trim();
    final cout = _coutCtrl.text.trim();

    final payload = <String, dynamic>{
      'voitureId': _vehicule!.id,
      'dateFlux': dt.toIso8601String(),
      'depart': _departCtrl.text.trim(),
      'destination': _destinationCtrl.text.trim(),
      if (_objetCtrl.text.trim().isNotEmpty) 'objet': _objetCtrl.text.trim(),
      if (_chauffeur != null) 'chauffeurId': _chauffeur!.id,
      if (km.isNotEmpty) 'kilometresParcourus': int.tryParse(km),
      if (cout.isNotEmpty) 'cout': double.tryParse(cout),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    try {
      final headers = await _authHeaders();
      final res = await _dio.post(
        'FluxTransports',
        data: payload,
        options: Options(headers: {...headers, 'Content-Type': 'application/json'}),
      );

      if (!mounted) return;

      if (res.statusCode == 201 || res.statusCode == 200) {
        _toast('Flux créé ✔');
        _go(AppRoutes.voituresFlux);
      } else {
        _toast('Création échouée (${res.statusCode})');
      }
    } on DioException catch (e) {
      _toast(e.response?.data?.toString() ?? e.message ?? 'Erreur réseau');
    } catch (e) {
      _toast(e.toString());
    }
  }

  // ========= UI =========
  @override
  Widget build(BuildContext context) {
    final routeNow = ModalRoute.of(context)?.settings.name ?? AppRoutes.voituresFluxAdd;

    final sections = AppMenu.buildDefaultSections(
      hasPaiementAlerts: () => true,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBarWithMenu(
        title: 'Créer un flux',
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
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    color: const Color(0xFF121214).withOpacity(.55),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppColors.kBg3),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final twoCols = c.maxWidth >= 720;
                            final field = (Widget w) =>
                            twoCols ? SizedBox(width: (c.maxWidth - 24) / 2, child: w) : w;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Créer un flux de transport',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                if (_loading) ...[
                                  const SizedBox(height: 8),
                                  const LinearProgressIndicator(minHeight: 2),
                                ],
                                const SizedBox(height: 18),

                                Wrap(
                                  spacing: 24,
                                  runSpacing: 14,
                                  children: [
                                    // Véhicule (obligatoire)
                                    field(_DropdownBox<_IdLabel>(
                                      label: 'Véhicule *',
                                      value: _vehicule,
                                      items: _vehicules,
                                      onChanged: (v) => setState(() => _vehicule = v),
                                      validator: (v) => v == null ? 'Obligatoire' : null,
                                    )),

                                    // Chauffeur (optionnel)
                                    field(_DropdownBox<_IdLabel>(
                                      label: 'Chauffeur (optionnel)',
                                      value: _chauffeur,
                                      items: _chauffeurs,
                                      onChanged: (v) => setState(() => _chauffeur = v),
                                    )),

                                    field(TextFormField(
                                      controller: _departCtrl,
                                      decoration: _dec('Départ *', hint: 'Ville / adresse'),
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                                    )),
                                    field(TextFormField(
                                      controller: _destinationCtrl,
                                      decoration: _dec('Destination *', hint: 'Ville / adresse'),
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                                    )),

                                    // Date
                                    field(GestureDetector(
                                      onTap: _pickDate,
                                      child: AbsorbPointer(
                                        child: TextFormField(
                                          decoration: _dec('Date *', hint: 'Choisir la date'),
                                          controller: TextEditingController(
                                            text: _date == null
                                                ? ''
                                                : '${_date!.day.toString().padLeft(2, '0')}/'
                                                '${_date!.month.toString().padLeft(2, '0')}/'
                                                '${_date!.year}',
                                          ),
                                          validator: (_) => _date == null ? 'Obligatoire' : null,
                                        ),
                                      ),
                                    )),

                                    // Heure
                                    field(GestureDetector(
                                      onTap: _pickTime,
                                      child: AbsorbPointer(
                                        child: TextFormField(
                                          decoration: _dec('Heure *', hint: 'Choisir l\'heure'),
                                          controller: TextEditingController(
                                            text: _time == null
                                                ? ''
                                                : '${_time!.hour.toString().padLeft(2, '0')}:'
                                                '${_time!.minute.toString().padLeft(2, '0')}',
                                          ),
                                          validator: (_) => _time == null ? 'Obligatoire' : null,
                                        ),
                                      ),
                                    )),

                                    // Objet (optionnel)
                                    field(TextFormField(
                                      controller: _objetCtrl,
                                      decoration: _dec('Objet (optionnel)', hint: 'Marchandises, mission…'),
                                    )),

                                    // Kilomètres & Coût (optionnels)
                                    field(TextFormField(
                                      controller: _kmCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: _dec('Kilomètres parcourus (optionnel)'),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return null;
                                        return int.tryParse(v) == null ? 'Nombre invalide' : null;
                                      },
                                    )),
                                    field(TextFormField(
                                      controller: _coutCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: _dec('Coût (TND) (optionnel)'),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return null;
                                        return double.tryParse(v) == null ? 'Nombre invalide' : null;
                                      },
                                    )),

                                    // Notes
                                    SizedBox(
                                      width: twoCols ? c.maxWidth : double.infinity,
                                      child: TextFormField(
                                        controller: _notesCtrl,
                                        maxLines: 3,
                                        decoration: _dec('Notes (optionnel)', hint: 'Détails, remarques...'),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 18),
                                const Divider(color: Colors.white24, height: 1),
                                const SizedBox(height: 14),

                                Row(
                                  children: [
                                    FilledButton.icon(
                                      icon: const Icon(Icons.check),
                                      label: const Text('Créer le flux'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.kOrange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: _submit,
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                        side: const BorderSide(color: AppColors.kBg3),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => Navigator.of(context).maybePop(),
                                      child: const Text('Annuler'),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
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
}

// Dropdown réutilisable
class _DropdownBox<T> extends FormField<T> {
  _DropdownBox({
    Key? key,
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    FormFieldValidator<T>? validator,
  }) : super(
    key: key,
    validator: validator,
    initialValue: value,
    builder: (state) {
      final current = state.value;
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFF1A1A1E),
          labelStyle: const TextStyle(color: AppColors.onDark60),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.kBg3),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.kOrange, width: 1.4),
          ),
          errorBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.redAccent),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          errorText: state.errorText,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: current,
            isExpanded: true,
            dropdownColor: const Color(0xFF1A1A1E),
            iconEnabledColor: Colors.white70,
            style: const TextStyle(color: Colors.white),
            items: items
                .map((e) => DropdownMenuItem<T>(value: e, child: Text(e.toString())))
                .toList(),
            onChanged: (v) {
              state.didChange(v);
              onChanged(v);
            },
          ),
        ),
      );
    },
  );
}
