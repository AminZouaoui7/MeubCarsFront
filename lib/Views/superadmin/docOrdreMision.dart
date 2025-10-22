import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:convert' as convert;

import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/background.dart';
import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/core/cache/cacheHelper.dart';
import 'package:meubcars/Data/Models/user_model.dart';

class Docordremision extends StatefulWidget {
    const Docordremision({super.key});

  @override
  State<Docordremision> createState() => _DocordremisionState();
}

class _DocordremisionState extends State<Docordremision> {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: EndPoint.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  final _fmt = DateFormat('dd/MM/yyyy HH:mm');
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOrdres();
  }

  Future<Map<String, String>> _authHeaders() async {
    final t = await CacheHelper.getData(key: 'token');
    final h = <String, String>{};
    if (t != null && t.toString().isNotEmpty) h['Authorization'] = 'Bearer $t';
    return h;
  }

  Future<UserModel?> _getCurrentUser() async {
    dynamic raw = await CacheHelper.getData(key: 'user');
    if (raw is String) {
      try {
        return UserModel.fromJson(Map<String, dynamic>.from(convert.jsonDecode(raw)));
      } catch (_) {}
    }
    return null;
  }

  Future<void> _fetchOrdres() async {
    try {
      final headers = await _authHeaders();
      final res = await _dio.get(
        'OrdresMission',
        options: Options(headers: headers),
      );
      setState(() {
        _rows = (res.data['rows'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openPdf(Map<String, dynamic> ordre) async {
    try {
      final voitureId = ordre['voitureId'];
      final headers = await _authHeaders();

      // 1️⃣ Charger la liste des pièces jointes
      final filesRes = await _dio.get(
        'voitures/$voitureId/pieces-jointes',
        options: Options(headers: headers),
      );

      final pieces = (filesRes.data as List).cast<Map>();

      // 2️⃣ Trouver la pièce jointe correspondant à l’ordre de mission
      final match = pieces.firstWhere(
            (p) => (p['titre'] ?? '').toString().contains(ordre['numero'] ?? ''),
        orElse: () => {},
      );

      if (match.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun PDF trouvé pour cet ordre')),
        );
        return;
      }

      final pieceId = match['id'];
      if (pieceId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pièce jointe invalide (id manquant)')),
        );
        return;
      }

      // 3️⃣ Télécharger le fichier via le nouvel endpoint /download
      final resPdf = await _dio.get(
        'voitures/$voitureId/pieces-jointes/$pieceId/download',
        options: Options(headers: headers, responseType: ResponseType.bytes),
      );

      // 4️⃣ Convertir en bytes
      final bytes = resPdf.data is Uint8List
          ? resPdf.data
          : Uint8List.fromList(List<int>.from(resPdf.data));

      // 5️⃣ Ouvrir la prévisualisation PDF
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreview(
            build: (_) async => bytes,
            allowPrinting: true,
            allowSharing: true,
            canChangeOrientation: false,
            canChangePageFormat: false,
            pdfFileName: '${ordre['numero'] ?? 'OrdreMission'}.pdf',
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Erreur PDF: $e');
      debugPrintStack(stackTrace: st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur ouverture PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeNow = ModalRoute.of(context)?.settings.name ?? '/superadmin/Docordremision';
    final sections = AppMenu.buildDefaultSections();

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
            title: 'Ordres de mission',
            onNavigate: _navigate,
            homeRoute: AppRoutes.home,
            sections: sections,
            activeRoute: routeNow,
            currentUser: user,
          ),
            body: Stack(
              fit: StackFit.expand,
              children: [
                const BrandBackground(),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      color: Colors.black.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.bold, color: Colors.white),
                              dataTextStyle: const TextStyle(color: Colors.white70),
                              columns: const [
                                DataColumn(label: Text('N°')),
                                DataColumn(label: Text('Chauffeur')),
                                DataColumn(label: Text('Voiture')),
                                DataColumn(label: Text('Destination')),
                                DataColumn(label: Text('Départ')),
                                DataColumn(label: Text('Retour prévu')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: _rows.map((m) {
                                final num = m['numero'] ?? '-';
                                final chauffeur =
                                    m['chauffeur']?['nomComplet'] ?? m['chauffeurNom'] ?? '-';
                                final voiture =
                                    m['voiture']?['matricule'] ?? m['voitureMatricule'] ?? '-';
                                final dest = m['destination'] ?? '-';
                                final dep = m['dateDepart'] != null
                                    ? _fmt.format(DateTime.parse(m['dateDepart']))
                                    : '-';
                                final ret = m['dateRetourPrevue'] != null
                                    ? _fmt.format(DateTime.parse(m['dateRetourPrevue']))
                                    : '-';
                                return DataRow(cells: [
                                  DataCell(Text(num)),
                                  DataCell(Text(chauffeur)),
                                  DataCell(Text(voiture)),
                                  DataCell(Text(dest)),
                                  DataCell(Text(dep)),
                                  DataCell(Text(ret)),
                                  DataCell(Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.picture_as_pdf, color: Colors.blueAccent),
                                        tooltip: 'Voir PDF',
                                        onPressed: () => _openPdf(m),
                                      ),
                                    ],
                                  )),
                                ]);
                              }).toList(),
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
}
