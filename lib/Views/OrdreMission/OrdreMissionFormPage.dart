// lib/Views/Mission/ordre_mission_form_page.dart
import 'dart:convert' as convert;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/background.dart';
import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/core/cache/CacheHelper.dart';
import 'package:meubcars/Data/Models/user_model.dart';

class OrdreMissionFormPage extends StatefulWidget {
  const OrdreMissionFormPage({super.key});

  @override
  State<OrdreMissionFormPage> createState() => _OrdreMissionFormPageState();
}

class _OrdreMissionFormPageState extends State<OrdreMissionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: EndPoint.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  int? _voitureId;
  String? _voitureMatricule;
  String? _voitureLibelle;

  int? _chauffeurId;
  String? _chauffeurNom;

  final _lieuDepart = TextEditingController();
  final _destination = TextEditingController();
  final _objet = TextEditingController();
  final _client = TextEditingController();
  final _kmDepart = TextEditingController();
  final _notes = TextEditingController();

  final _accController = TextEditingController();
  final List<String> _accompagnateurs = [];

  final _fraisCarburant = TextEditingController();
  final _fraisPeage = TextEditingController();
  final _autresFrais = TextEditingController();

  DateTime _dateDepart = DateTime.now();
  DateTime _dateRetour = DateTime.now().add(const Duration(days: 1));
  final _fmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void dispose() {
    _lieuDepart.dispose();
    _destination.dispose();
    _objet.dispose();
    _client.dispose();
    _kmDepart.dispose();
    _notes.dispose();
    _accController.dispose();
    _fraisCarburant.dispose();
    _fraisPeage.dispose();
    _autresFrais.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _authHeaders() async {
    final t = await CacheHelper.getData(key: 'token');
    return {
      if (t != null && t.toString().isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

  // ---------- Pick voiture ----------
  Future<void> _pickVoiture() async {
    final headers = await _authHeaders();
    final res = await _dio.get('Voitures', options: Options(headers: headers));
    final List<Map<String, dynamic>> list =
    (res.data as List).map((e) => Map<String, dynamic>.from(e)).toList();

    final search = TextEditingController();
    List<Map<String, dynamic>> filtered = List.of(list);

    final choice = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Choisir une voiture'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Rechercher (matricule, marque, modèle)',
                  ),
                  onChanged: (q) {
                    final Q = q.trim().toLowerCase();
                    setSt(() {
                      filtered = Q.isEmpty
                          ? List.of(list)
                          : list.where((m) {
                        final idx =
                        '${m['matricule'] ?? ''} ${m['marque'] ?? ''} ${m['modele'] ?? ''}'
                            .toLowerCase();
                        return idx.contains(Q);
                      }).toList();
                    });
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 400,
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                    const Divider(height: 1, thickness: .4),
                    itemBuilder: (_, i) {
                      final m = filtered[i];
                      final lib =
                      '${m['marque'] ?? ''} ${m['modele'] ?? ''}'.trim();
                      return ListTile(
                        leading: const Icon(Icons.directions_car_filled),
                        title: Text(lib.isEmpty ? '(sans libellé)' : lib),
                        subtitle: Text('Matricule: ${m['matricule'] ?? ''}'),
                        onTap: () => Navigator.pop(ctx, {
                          'id': m['id'],
                          'matricule': m['matricule'],
                          'libelle': lib,
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );

    if (choice != null) {
      setState(() {
        _voitureId = choice['id'] as int;
        _voitureMatricule = (choice['matricule'] ?? '').toString();
        _voitureLibelle = (choice['libelle'] ?? '').toString();
      });

      // 🚀 Charger le chauffeur lié à cette voiture
      try {
        final chauffeurRes = await _dio.get(
          'Chauffeur/voiture/${_voitureId}',
          options: Options(headers: headers),
        );
        if (chauffeurRes.statusCode == 200 && chauffeurRes.data != null) {
          final ch = Map<String, dynamic>.from(chauffeurRes.data);
          if (ch['id'] != null) {
            setState(() {
              _chauffeurId = ch['id'];
              _chauffeurNom =
                  (ch['nomComplet'] ?? '${ch['prenom'] ?? ''} ${ch['nom'] ?? ''}')
                      .toString()
                      .trim();
              if (_chauffeurNom!.isEmpty) _chauffeurNom = 'Inconnu';
            });
          }
        }
      } catch (e) {
        debugPrint('⚠️ Erreur chauffeur: $e');
      }
    }
  }

  // ---------- Pick chauffeur ----------
  Future<void> _pickChauffeur() async {
    final headers = await _authHeaders();
    final res = await _dio.get('Chauffeur', options: Options(headers: headers));
    final list =
    (res.data as List).map((e) => Map<String, dynamic>.from(e)).toList();

    final search = TextEditingController();
    List<Map<String, dynamic>> filtered = List.of(list);

    final choice = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Choisir un chauffeur'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Rechercher par nom',
                  ),
                  onChanged: (q) {
                    final Q = q.trim().toLowerCase();
                    setSt(() {
                      filtered = Q.isEmpty
                          ? List.of(list)
                          : list.where((m) {
                        final idx =
                        '${m['nomComplet'] ?? m['nom'] ?? ''}'
                            .toLowerCase();
                        return idx.contains(Q);
                      }).toList();
                    });
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 400,
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                    const Divider(height: 1, thickness: .4),
                    itemBuilder: (_, i) {
                      final m = filtered[i];
                      final nom = (m['nomComplet'] ??
                          '${m['prenom'] ?? ''} ${m['nom'] ?? ''}')
                          .toString()
                          .trim();
                      return ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: Text(nom),
                        onTap: () =>
                            Navigator.pop(ctx, {'id': m['id'], 'nom': nom}),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );

    if (choice != null) {
      setState(() {
        _chauffeurId = choice['id'] as int;
        _chauffeurNom = (choice['nom'] ?? '').toString().trim();
        if (_chauffeurNom!.isEmpty) _chauffeurNom = 'Inconnu';
      });
    }
  }

  double? _toDouble(String s) {
    final t = s.trim().replaceAll(',', '.');
    final v = double.tryParse(t);
    return v == null || v.isNaN ? null : v;
  }

  Future<void> _pickDateTime({
    required DateTime initial,
    required void Function(DateTime) onPicked,
  }) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    onPicked(DateTime(d.year, d.month, d.day, t?.hour ?? 9, t?.minute ?? 0));
  }

  // ---------- Submit ----------
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ Utilise uniquement le chauffeur choisi
    final chauffeurNomFinal =
    (_chauffeurNom?.trim().isNotEmpty ?? false) ? _chauffeurNom!.trim() : 'Inconnu';

    final body = {
      'voitureId': _voitureId,
      'chauffeurId': _chauffeurId,
      'chauffeurNom': chauffeurNomFinal,
      'lieuDepart': _lieuDepart.text.trim(),
      'destination': _destination.text.trim(),
      'objet': _objet.text.trim(),
      'client': _client.text.trim().isEmpty ? null : _client.text.trim(),
      'dateDepart': _dateDepart.toIso8601String(),
      'dateRetourPrevue': _dateRetour.toIso8601String(),
      'kmDepart': int.tryParse(_kmDepart.text.trim()),
      'accompagnateurs': _accompagnateurs,
      'fraisCarburant': _toDouble(_fraisCarburant.text),
      'fraisPeage': _toDouble(_fraisPeage.text),
      'autresFrais': _toDouble(_autresFrais.text),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };

    print('🚗 chauffeurId=$_chauffeurId');
    print('🚗 chauffeurNom=$_chauffeurNom');
    print('📤 Body envoyé: ${convert.jsonEncode(body)}');

    try {
      final headers = await _authHeaders();
      final res = await _dio.post(
        'OrdresMission',
        data: body,
        options: Options(headers: headers),
      );

      if (res.statusCode == 201) {
        final ordre = Map<String, dynamic>.from(res.data as Map);

        final bytes = await _buildPdf(ordre);
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfPreview(
              build: (_) async => bytes,
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              initialPageFormat: PdfPageFormat.a4,
            ),
          ),
        );
      } else {
        throw Exception('Erreur serveur ${res.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(e.toString())),
      );
    }
  }

  // ---------- PDF ----------
  Future<Uint8List> _buildPdf(Map<String, dynamic> ordre) async {
    final doc = pw.Document();
    final base = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    final chauffeurNom =
    (ordre['chauffeurNom'] ?? ordre['chauffeur']?['nomComplet'] ?? '').toString();

    final voitureInfo = [
      ordre['voiture']?['marque'],
      ordre['voiture']?['modele'],
      ordre['voiture']?['matricule']
    ].whereType<String>().join(' ');

    pw.Widget infoRow(String left, String right) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Container(width: 140, child: pw.Text(left, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(right)),
        ],
      ),
    );

    doc.addPage(
      pw.Page(
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text('Ordre De Mission', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Informations', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            infoRow('Moyen de transport', voitureInfo),
            infoRow('Chauffeur', chauffeurNom),
            infoRow('Objet de mission', '${ordre['objet'] ?? ''}'),
            infoRow('Client', '${ordre['client'] ?? ''}'),
            infoRow('Départ', fmt.format(DateTime.parse(ordre['dateDepart']))),
            infoRow('Retour prévu', fmt.format(DateTime.parse(ordre['dateRetourPrevue']))),
            infoRow('Lieu de départ', '${ordre['lieuDepart'] ?? ''}'),
            infoRow('Destination', '${ordre['destination'] ?? ''}'),
          ],
        ),
      ),
    );
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final routeNow = ModalRoute.of(context)?.settings.name ?? '/missions/new';
    final sections = AppMenu.buildDefaultSections();

    void _navigate(String route) {
      final s = Scaffold.maybeOf(context);
      if (s?.isDrawerOpen ?? false) Navigator.of(context).pop();
      if (ModalRoute.of(context)?.settings.name == route) return;
      Navigator.of(context).pushReplacementNamed(route);
    }

    return Scaffold(
      drawer: AppSideMenu(
        activeRoute: routeNow,
        sections: sections,
        onNavigate: _navigate,
      ),
      appBar: AppBarWithMenu(
        title: 'Nouvel ordre de mission',
        onNavigate: _navigate,
        homeRoute: AppRoutes.home,
        sections: sections,
        activeRoute: routeNow,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  // Voiture
                  SizedBox(
                    width: 360,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Voiture'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _voitureId == null
                                  ? 'Aucune'
                                  : '${_voitureLibelle ?? ''} · ${_voitureMatricule ?? ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _pickVoiture,
                            icon: const Icon(Icons.directions_car_filled),
                            label: const Text('Choisir'),
                          )
                        ],
                      ),
                    ),
                  ),

                  // Chauffeur
                  SizedBox(
                    width: 360,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Chauffeur'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _chauffeurId == null ? 'Aucun' : (_chauffeurNom ?? ''),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _pickChauffeur,
                            icon: const Icon(Icons.badge_outlined),
                            label: const Text('Choisir'),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Enregistrer & Prévisualiser PDF'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
