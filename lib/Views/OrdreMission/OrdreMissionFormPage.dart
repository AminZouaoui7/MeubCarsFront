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
        baseUrl: EndPoint.baseUrl, // ex: http://10.0.2.2:7178/api
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    // ---- Etat / champs
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

    // Accompagnateurs
    final _accController = TextEditingController();
    final List<String> _accompagnateurs = [];

    // Frais (enregistrés mais pas imprimés)
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
      final h = <String, String>{};
      if (t != null && t.toString().isNotEmpty) h['Authorization'] = 'Bearer $t';
      return h;
    }

    // ---------- Current user for AppBar ----------
    Future<UserModel?> _getCurrentUser() async {
      dynamic raw;
      for (final key in ['user', 'currentUser', 'profile']) {
        raw = await CacheHelper.getData(key: key);
        if (raw != null) break;
      }

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
      } catch (_) {}

      final name = await CacheHelper.getData(key: 'nomComplet') ??
          await CacheHelper.getData(key: 'fullName') ??
          await CacheHelper.getData(key: 'name');

      final email = await CacheHelper.getData(key: 'email');
      final avatar = await CacheHelper.getData(key: 'avatarUrl') ??
          await CacheHelper.getData(key: 'avatar');
      final id = await CacheHelper.getData(key: 'userId') ??
          await CacheHelper.getData(key: 'id');

      if (name != null && name.toString().trim().isNotEmpty) {
        return UserModel.fromJson({
          'id': (id is int) ? id : int.tryParse('${id ?? 0}') ?? 0,
          'nomComplet': name.toString(),
          'email': email?.toString(),
          'avatarUrl': avatar?.toString(),
        });
      }
      return null;
    }


    Future<void> _pickVoiture() async {
      final headers = await _authHeaders();

      final res = await _dio.get('Voitures', options: Options(headers: headers));
      final List<Map<String, dynamic>> list =
      (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

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
                          leading: const Icon(Icons.directions_car_filled,
                              ),
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

        // 🚀 Charger le chauffeur lié
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
                _chauffeurNom = ch['nomComplet'] ??
                    '${ch['prenom'] ?? ''} ${ch['nom'] ?? ''}'.trim();
              });

            } else {

            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur chauffeur: $e');
        }
      }
    }

    Future<void> _pickChauffeur() async {
      final headers = await _authHeaders();
      final res = await _dio.get('Chauffeur', options: Options(headers: headers));
      final list = (res.data as List).map((e) => Map<String, dynamic>.from(e)).toList();

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
                          '${m['nomComplet'] ?? m['nom'] ?? ''}'.toLowerCase();
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
                          onTap: () => Navigator.pop(ctx, {'id': m['id'], 'nom': nom}),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
            ],
          ),
        ),
      );

      if (choice != null) {
        setState(() {
          _chauffeurId = choice['id'] as int;
          _chauffeurNom = (choice['nom'] ?? '').toString();
        });

        // 🚀 Charger la voiture associée à ce chauffeur
        try {
          final voitureRes = await _dio.get(
            'Chauffeur/chauffeur/${_chauffeurId}',
            options: Options(headers: headers),
          );
          if (voitureRes.statusCode == 200 && voitureRes.data != null) {
            final v = Map<String, dynamic>.from(voitureRes.data);
            if (v['id'] != null) {
              setState(() {
                _voitureId = v['id'];
                _voitureMatricule = v['matricule'];
                _voitureLibelle = v['libelle'] ?? "${v['marque']} ${v['modele']}";
              });

            } else {

            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur voiture: $e');
        }
      }
    }

    // ---------- Helpers ----------
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
// ---------- Submit ----------
    Future<void> _submit() async {
      if (!_formKey.currentState!.validate()) return;

      final body = {
        'voitureId': _voitureId,
        'chauffeurId': _chauffeurId,
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
      };

      try {
        final headers = await _authHeaders();
        final res = await _dio.post(
          'OrdresMission',
          data: body,
          options: Options(headers: headers),
        );

        if (res.statusCode == 201) {
          final ordre = Map<String, dynamic>.from(res.data as Map);

          // 1️⃣ Générer le PDF localement
          final bytes = await _buildPdf(ordre);

          // 2️⃣ Convertir le PDF en base64
          final base64Pdf = convert.base64Encode(bytes);

          // 3️⃣ Envoyer le PDF au backend (sauvegarde auto dans la documentation)
          if (_voitureId != null) {
            try {
              await _dio.post(
                'voitures/${_voitureId}/pieces-jointes/upload-base64',
                data: {
                  'base64File': base64Pdf,
                  'titre':
                  'Ordre de mission - ${ordre['numero'] ?? _voitureMatricule ?? ''}',
                },
                options: Options(headers: headers),
              );
              debugPrint('✅ PDF enregistré côté backend');
            } catch (e) {
              debugPrint('⚠️ Erreur enregistrement PDF: $e');
            }
          }

          // 4️⃣ Ouvrir la prévisualisation PDF locale
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
                pdfFileName:
                '${(ordre['numero'] ?? 'ordre_mission').toString().replaceAll(' ', '_')}.pdf',
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

      final city = (ordre['villePourDate'] ?? 'Hammam Sousse').toString();
      final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
      final fmt = DateFormat('dd/MM/yyyy HH:mm');

      List<String> _accFromApi() {
        final a = ordre['accompagnateurs'];
        return (a is List) ? a.whereType<String>().toList() : const [];
      }

      // --- valeurs venant de l'API (voiture/chauffeur) ---
      final rawVoitureLib = (ordre['voitureLibelle'] ?? '').toString().trim().isNotEmpty
          ? ordre['voitureLibelle']
          : '${ordre['voiture']?['marque'] ?? ''} ${ordre['voiture']?['modele'] ?? ''}';

      // ⬇️ on retire l'année (formats: "· 2019" ou "- 2019")
      final voitureSansAnnee =
      (rawVoitureLib ?? '').toString().replaceAll(RegExp(r'\s*[·\-]\s*\d{4}\b'), '').trim();

      final matriculeVoiture =
      (ordre['voitureMatricule'] ?? ordre['voiture']?['matricule'] ?? '').toString();

      final chauffeurNom =
      (ordre['chauffeurNom'] ?? ordre['chauffeur']?['nomComplet'] ?? '').toString();

      // --- libellé "Moyen de transport" ---
      final moyenTransportRaw = (ordre['moyenTransport'] ?? '').toString().trim();
      final immatriculeRaw = (ordre['immatricule'] ?? '').toString().trim();

      final moyenTransportValue = [
        moyenTransportRaw.isEmpty ? voitureSansAnnee : moyenTransportRaw,
        (immatriculeRaw.isEmpty ? matriculeVoiture : immatriculeRaw),
      ].where((s) => s.isNotEmpty).join(' - ');

      // --- table helper avec espacement vertical ---
      pw.Widget infoTable(List<List<String>> items) => pw.Table(
        columnWidths: {0: const pw.FixedColumnWidth(150), 1: const pw.FlexColumnWidth()},
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: items
            .map(
              (row) => pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Text(row[0],
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Text(row[1]),
              ),
            ],
          ),
        )
            .toList(),
      );

      final acc = _accFromApi().join(', ');

      doc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(28),
            theme: pw.ThemeData.withFont(base: base, bold: bold),
          ),
          build: (ctx) => [
            // En-tête
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Meublatex',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('H Sousse - Tél. 73 308 777', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('N° ${ordre['numero'] ?? ''}', style: const pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 4),
                    pw.Text('$city le $today', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text('Ordre De Mission',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 16),

            pw.Text('Informations',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),

            infoTable([
              ['Moyen de transport', moyenTransportValue.isEmpty ? '-' : moyenTransportValue],
              ['Chauffeur', chauffeurNom.isEmpty ? '-' : chauffeurNom],
              ['Objet de mission', '${ordre['objet'] ?? ''}'],
              ['Client', '${ordre['client'] ?? ''}'],
              ['Départ', fmt.format(DateTime.parse(ordre['dateDepart']))],
              ['Retour prévu', fmt.format(DateTime.parse(ordre['dateRetourPrevue']))],
              ['Lieu de départ', '${ordre['lieuDepart'] ?? ''}'],
              ['Destination', '${ordre['destination'] ?? ''}'],
              ['KM départ', '${ordre['kmDepart'] ?? ''}'],
              if (acc.isNotEmpty) ['Accompagnateurs', acc],
            ]),

            pw.SizedBox(height: 28),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(children: [
                  pw.Text('Signature Responsable'),
                  pw.SizedBox(height: 40),
                  pw.Container(width: 160, height: 1, color: PdfColors.grey700),
                ]),
                pw.Column(children: [
                  pw.Text('Signature Chauffeur'),
                  pw.SizedBox(height: 40),
                  pw.Container(width: 160, height: 1, color: PdfColors.grey700),
                ]),
              ],
            ),
          ],
        ),
      );

      return doc.save();
    }
    void _resetSelection() {
      setState(() {
        _voitureId = null;
        _voitureMatricule = null;
        _voitureLibelle = null;
        _chauffeurId = null;
        _chauffeurNom = null;
        _accompagnateurs.clear();
      });


    }


    @override
    Widget build(BuildContext context) {
      final routeNow = ModalRoute.of(context)?.settings.name ?? '/missions/new';

      final sections = AppMenu.buildDefaultSections(
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
          final user = snap.data;

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
              currentUser: user, // ✅ shows real name/initials/avatar
            ),
            body: Stack(
              fit: StackFit.expand,
              children: [
                const BrandBackground(),
                SafeArea(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            // ---- Voiture (picker) ----
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
                                            : '${_voitureLibelle ?? ''}  ·  ${_voitureMatricule ?? ''}',
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

                            // ---- Chauffeur (picker) ----
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

                            // ---- Infos mission ----
                            SizedBox(
                              width: 360,
                              child: TextFormField(
                                controller: _objet,
                                decoration:
                                const InputDecoration(labelText: 'Objet de la mission'),
                                textInputAction: TextInputAction.next,
                                validator: (v) => (v == null || v.isEmpty) ? 'Obligatoire' : null,
                              ),
                            ),
                            SizedBox(
                              width: 360,
                              child: TextFormField(
                                controller: _client,
                                decoration:
                                const InputDecoration(labelText: 'Client (optionnel)'),
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                            SizedBox(
                              width: 360,
                              child: TextFormField(
                                controller: _lieuDepart,
                                decoration:
                                const InputDecoration(labelText: 'Lieu de départ'),
                                textInputAction: TextInputAction.next,
                                validator: (v) => (v == null || v.isEmpty) ? 'Obligatoire' : null,
                              ),
                            ),
                            SizedBox(
                              width: 360,
                              child: TextFormField(
                                controller: _destination,
                                decoration: const InputDecoration(labelText: 'Destination'),
                                textInputAction: TextInputAction.next,
                                validator: (v) => (v == null || v.isEmpty) ? 'Obligatoire' : null,
                              ),
                            ),

                            // Dates
                            SizedBox(
                              width: 360,
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Départ'),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(_fmt.format(_dateDepart))),
                                    TextButton.icon(
                                      onPressed: () => _pickDateTime(
                                        initial: _dateDepart,
                                        onPicked: (d) => setState(() => _dateDepart = d),
                                      ),
                                      icon: const Icon(Icons.event),
                                      label: const Text('Choisir'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 360,
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Retour prévu'),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(_fmt.format(_dateRetour))),
                                    TextButton.icon(
                                      onPressed: () => _pickDateTime(
                                        initial: _dateRetour,
                                        onPicked: (d) => setState(() => _dateRetour = d),
                                      ),
                                      icon: const Icon(Icons.event),
                                      label: const Text('Choisir'),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // KM départ
                            SizedBox(
                              width: 360,
                              child: TextFormField(
                                controller: _kmDepart,
                                decoration: const InputDecoration(
                                    labelText: 'Kilométrage départ (optionnel)'),
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                              ),
                            ),

                            // ---- Accompagnateurs ----
                            SizedBox(
                              width: 740,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Accompagnateurs'),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: -8,
                                    children: [
                                      for (final n in _accompagnateurs)
                                        InputChip(
                                          label: Text(n),
                                          onDeleted: () =>
                                              setState(() => _accompagnateurs.remove(n)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _accController,
                                          decoration: const InputDecoration(
                                            hintText: 'Nom / prénom',
                                            border: OutlineInputBorder(),
                                          ),
                                          onSubmitted: (_) {
                                            final s = _accController.text.trim();
                                            if (s.isNotEmpty) {
                                              setState(() {
                                                _accompagnateurs.add(s);
                                                _accController.clear();
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.icon(
                                        onPressed: () {
                                          final s = _accController.text.trim();
                                          if (s.isNotEmpty) {
                                            setState(() {
                                              _accompagnateurs.add(s);
                                              _accController.clear();
                                            });
                                          }
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text('Ajouter'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // ---- Frais (stockés, non imprimés) ----

                            SizedBox(
                              width: 240,
                              child: TextFormField(
                                controller: _fraisPeage,
                                decoration: const InputDecoration(labelText: 'Frais péage (DH)'),
                                keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                            SizedBox(
                              width: 240,
                              child: TextFormField(
                                controller: _autresFrais,
                                decoration: const InputDecoration(labelText: 'Autres frais (DH)'),
                                keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                    Row(
                      children: [
                        // ✅ Bouton Enregistrer
                        FilledButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Enregistrer & Prévisualiser PDF'),
                        ),
                        const SizedBox(width: 12),

                        // ✅ Nouveau bouton Reset
                        OutlinedButton.icon(
                          onPressed: _resetSelection,
                          icon: const Icon(Icons.refresh, ),
                          label: const Text(
                            'Réinitialiser',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }
