import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import 'package:meubcars/Data/Models/paiment.dart';
import 'package:meubcars/Data/Models/user_model.dart';
import 'package:meubcars/core/cache/CacheHelper.dart';
import 'package:meubcars/Data/remote/auth_remote.dart';
import 'package:meubcars/Data/repositories/auth_repository.dart';
import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/background.dart';

// PDF
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class PaiementsHistoryPage extends StatefulWidget {
  final int? voitureId;
  const PaiementsHistoryPage({super.key, this.voitureId});

  @override
  State<PaiementsHistoryPage> createState() => _PaiementsHistoryPageState();
}
class _PaiementsHistoryPageState extends State<PaiementsHistoryPage> {
  PaiementsApi? _api;
  List<MenuSection> _sections = []; // ✅ No more late — initialized empty
  Future<List<PaiementVM>>? _future;
  final Dio _dio = Dio(BaseOptions(baseUrl: EndPoint.baseUrl));

  final Map<int, String> _carMatricules = {};
  PaymentType? _type;
  DateTimeRange? _range;

  final _fmtMonthLong = DateFormat('MMMM yyyy', 'fr_FR');
  final _fmtMonthShort = DateFormat('MM/yyyy', 'fr_FR');
  final _fmtNoSym =
  NumberFormat.currency(locale: 'fr_FR', symbol: '', decimalDigits: 3);

  UserModel? _currentUser;
  String get _activeRoute => AppRoutes.paiementsHistory;

  @override
  void initState() {
    super.initState();

    // ✅ Initialize safely (no race condition)
    try {
      _sections = AppMenu.buildDefaultSections(hasPaiementAlerts: () => false);
    } catch (e) {
      debugPrint('⚠️ Error initializing _sections: $e');
      _sections = [];
    }

    _loadCurrentUser();
    _init();
  }

  Future<void> _init() async {
    try {
      _api = await PaiementsApi.authed();
      _reload();
    } catch (e) {
      debugPrint('⚠️ PaiementsApi init failed: $e');
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final repo = AuthRepository(AuthRemote());
      final user = await repo.getCachedUser();
      if (user != null && mounted) setState(() => _currentUser = user);
    } catch (e) {
      debugPrint('⚠️ loadCurrentUser error: $e');
    }
  }

  Future<void> _ensureMatricules(Iterable<int> voitureIds) async {
    final token = await CacheHelper.getData(key: 'token');
    if (token == null) return;
    final headers = {'Authorization': 'Bearer $token'};

    for (final id in voitureIds) {
      if (_carMatricules.containsKey(id)) continue;
      try {
        final res =
        await _dio.get('Voitures/$id', options: Options(headers: headers));
        final mat = res.data['matricule']?.toString();
        _carMatricules[id] = (mat != null && mat.isNotEmpty) ? mat : '—';
      } catch (_) {
        _carMatricules[id] = '—';
      }
    }
    if (mounted) setState(() {});
  }

  void _reload() {
    if (_api == null) return;
    setState(() {
      _future = _api!.history(
        voitureId: widget.voitureId,
        type: _type,
        from: _range?.start,
        to: _range?.end,
      );
    });
  }

  List<PaymentType> get _allTypesOrder => const [
    PaymentType.Assurance,
    PaymentType.CarteGrise,
    PaymentType.Vignette,
    PaymentType.VisiteTechnique,
    PaymentType.Entretien,
    PaymentType.Taxe,
    PaymentType.Autre,
  ];

  Map<String, Map<PaymentType, double>> _buildMonthlyPivot(
      List<PaiementVM> rows) {
    final map = <String, Map<PaymentType, double>>{};
    for (final p in rows) {
      final key =
          '${p.datePaiement.year}-${p.datePaiement.month.toString().padLeft(2, '0')}';
      final row =
      map.putIfAbsent(key, () => {for (final t in _allTypesOrder) t: 0.0});
      row[p.type] = (row[p.type] ?? 0) + p.montant;
    }
    return map;
  }

  Map<int, Map<String, Map<PaymentType, double>>> _buildPivotByCar(
      List<PaiementVM> rows) {
    final map = <int, Map<String, Map<PaymentType, double>>>{};
    for (final p in rows) {
      final carMap = map.putIfAbsent(p.voitureId, () => {});
      final key =
          '${p.datePaiement.year}-${p.datePaiement.month.toString().padLeft(2, '0')}';
      final month =
      carMap.putIfAbsent(key, () => {for (final t in _allTypesOrder) t: 0.0});
      month[p.type] = (month[p.type] ?? 0) + p.montant;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final chips = Wrap(
      spacing: 8,
      children: [
        DropdownButton<PaymentType?>(
          value: _type,
          hint: const Text('Type'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Tous')),
            DropdownMenuItem(value: PaymentType.Assurance, child: Text('Assurance')),
            DropdownMenuItem(value: PaymentType.CarteGrise, child: Text('Carte grise')),
            DropdownMenuItem(value: PaymentType.Vignette, child: Text('Vignette')),
            DropdownMenuItem(value: PaymentType.VisiteTechnique, child: Text('Visite technique')),
            DropdownMenuItem(value: PaymentType.Entretien, child: Text('Entretien')),
            DropdownMenuItem(value: PaymentType.Taxe, child: Text('Taxe')),
          ],
          onChanged: (v) {
            setState(() => _type = v);
            _reload();
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(_range == null
              ? 'Période'
              : '${DateFormat('dd/MM/yy').format(_range!.start)} → ${DateFormat('dd/MM/yy').format(_range!.end)}'),
          onPressed: _pickRange,
        ),
        if (_type != null || _range != null)
          ElevatedButton.icon(
            icon: const Icon(Icons.clear, size: 18),
            label: const Text('Réinitialiser'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _type = null;
                _range = null;
              });
              _reload();
            },
          ),
      ],
    );

    return Scaffold(
      drawer: AppSideMenu(
        activeRoute: _activeRoute,
        onNavigate: _go,
        sections: _sections,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const BrandBackground(),
          SafeArea(
            child: Column(
              children: [
                AppBarWithMenu(
                  title: 'Historique des paiements',
                  onNavigate: _go,
                  sections: _sections,
                  activeRoute: _activeRoute,
                  currentUser: _currentUser,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: FutureBuilder<List<PaiementVM>>(
                      future: _future,
                      builder: (ctx, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Center(
                            child: Text('Erreur: ${snap.error}',
                                style: const TextStyle(color: Colors.red)),
                          );
                        }
                        final data = snap.data ?? [];
                        if (data.isEmpty) {
                          return const Center(child: Text('Aucun paiement.'));
                        }

                        final voitureIds = data.map((p) => p.voitureId).toSet();
                        _ensureMatricules(voitureIds);

                        final pivot = _buildMonthlyPivot(data);
                        final monthKeys = pivot.keys.toList()
                          ..sort((a, b) => b.compareTo(a));
                        final byCar = _buildPivotByCar(data);

                        final tableGlobal = _MonthlyPivotTable(
                          monthKeys: monthKeys,
                          pivot: pivot,
                          allTypes: _allTypesOrder,
                          labelOf: (t) => paymentTypeToLabel(t),
                          fmtMonth: _fmtMonthLong,
                          fmtTnd: (v) => _fmtNoSym.format(v),
                        );

                        final typesNoAutre = _allTypesOrder
                            .where((t) => t != PaymentType.Autre)
                            .toList();

                        final tableAllCars = _MonthlyPivotTableAllCars(
                          byCar: byCar,
                          getMatricule: (id) => _carMatricules[id] ?? '—',
                          allTypes: typesNoAutre,
                          labelOf: (t) => paymentTypeToLabel(t),
                          fmtMonth: _fmtMonthShort,
                          fmtTnd: (v) => _fmtNoSym.format(v),
                        );

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              chips,
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Tableau financier global',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  IconButton(
                                    icon: const Icon(Icons.picture_as_pdf),
                                    tooltip: 'Exporter en PDF',
                                    onPressed: () =>
                                        _exportGlobalPdf(pivot, _allTypesOrder),
                                  ),
                                ],
                              ),
                              Card(margin: const EdgeInsets.all(8), child: tableGlobal),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Tableau financier toutes voitures',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  IconButton(
                                    icon: const Icon(Icons.picture_as_pdf),
                                    tooltip: 'Exporter en PDF',
                                    onPressed: () =>
                                        _exportAllCarsPdf(byCar, typesNoAutre),
                                  ),
                                ],
                              ),
                              Card(margin: const EdgeInsets.all(8), child: tableAllCars),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// ⬇️ (Keep _exportGlobalPdf, _exportAllCarsPdf, _pickRange, _go unchanged)


  Future<void> _exportGlobalPdf(
      Map<String, Map<PaymentType, double>> pivot, List<PaymentType> types) async {
    final doc = pw.Document();

    pw.ImageProvider? logo;
    try {
      logo = await imageFromAssetBundle('assets/images/avatar.png');
    } catch (_) {
      logo = null;
    }

    final keys = pivot.keys.toList()..sort((a, b) => b.compareTo(a));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 100,
                    height: 100,
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text('Tableau Financier - Global',
                style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.brown800)),
            pw.Divider(thickness: 1, color: PdfColors.brown400),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'MeubLaTex Sousse - Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) {
          final tableData = keys.map((k) {
            final parts = k.split('-');
            final ym = DateTime(int.parse(parts[0]), int.parse(parts[1]));
            final map = pivot[k]!;
            final total = map.values.reduce((a, b) => a + b);
            return [
              DateFormat('MMMM yyyy', 'fr_FR').format(ym),
              ...types.map((t) => _fmtNoSym.format(map[t] ?? 0)),
              _fmtNoSym.format(total),
            ];
          }).toList();

          return [
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Mois', ...types.map(paymentTypeToLabel), 'Total'],
              data: tableData,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
              headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.brown700),
              cellAlignment: pw.Alignment.centerRight,
              cellStyle: const pw.TextStyle(fontSize: 11),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              columnWidths: {0: const pw.FlexColumnWidth(1.5)},
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'Tableau_Global.pdf',
      onLayout: (format) async => doc.save(),
    );
  }

  Future<void> _exportAllCarsPdf(
      Map<int, Map<String, Map<PaymentType, double>>> byCar,
      List<PaymentType> types) async {
    final doc = pw.Document();

    pw.ImageProvider? logo;
    try {
      logo = await imageFromAssetBundle('assets/images/avatar.png');
    } catch (_) {
      logo = null;
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 150,
                    height: 150,
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text('Tableau Financier - Toutes Voitures',
                style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.brown800)),
            pw.Divider(thickness: 1, color: PdfColors.brown400),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'MeubLaTex Sousse - Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) {
          final rows = <List<String>>[];
          byCar.forEach((id, months) {
            final mat = _carMatricules[id] ?? '—';
            months.forEach((key, data) {
              final parts = key.split('-');
              final ym = DateTime(int.parse(parts[0]), int.parse(parts[1]));
              final total = data.values.reduce((a, b) => a + b);
              rows.add([
                mat,
                DateFormat('MM/yyyy', 'fr_FR').format(ym),
                ...types.map((t) => _fmtNoSym.format(data[t] ?? 0)),
                _fmtNoSym.format(total),
              ]);
            });
          });

          return [
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Matricule', 'Mois', ...types.map(paymentTypeToLabel), 'Total'],
              data: rows,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
              headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.brown700),
              cellAlignment: pw.Alignment.centerRight,
              cellStyle: const pw.TextStyle(fontSize: 10.5),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1),
              },
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'Tableau_Toutes_Voitures.pdf',
      onLayout: (format) async => doc.save(),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (r != null) {
      setState(() => _range = r);
      _reload();
    }
  }

  void _go(String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.pushReplacementNamed(context, route);
  }
}
class _MonthlyPivotTable extends StatelessWidget {
  final List<String> monthKeys;
  final Map<String, Map<PaymentType, double>> pivot;
  final List<PaymentType> allTypes;
  final String Function(PaymentType) labelOf;
  final DateFormat fmtMonth;
  final String Function(num) fmtTnd;

  const _MonthlyPivotTable({
    required this.monthKeys,
    required this.pivot,
    required this.allTypes,
    required this.labelOf,
    required this.fmtMonth,
    required this.fmtTnd,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Mois')),
          ...allTypes.map((t) => DataColumn(label: Text(labelOf(t)))),
          const DataColumn(label: Text('Total')),
        ],
        rows: monthKeys.map((k) {
          final parts = k.split('-');
          final ym = DateTime(int.parse(parts[0]), int.parse(parts[1]));
          final map = pivot[k]!;
          final total = map.values.reduce((a, b) => a + b);
          return DataRow(cells: [
            DataCell(Text(fmtMonth.format(ym))),
            ...allTypes.map((t) => DataCell(Text(fmtTnd(map[t] ?? 0)))),
            DataCell(Text(fmtTnd(total), style: const TextStyle(fontWeight: FontWeight.bold))),
          ]);
        }).toList(),
      ),
    );
  }
}

class _MonthlyPivotTableAllCars extends StatelessWidget {
  final Map<int, Map<String, Map<PaymentType, double>>> byCar;
  final String Function(int) getMatricule;
  final List<PaymentType> allTypes;
  final String Function(PaymentType) labelOf;
  final DateFormat fmtMonth;
  final String Function(num) fmtTnd;

  const _MonthlyPivotTableAllCars({
    required this.byCar,
    required this.getMatricule,
    required this.allTypes,
    required this.labelOf,
    required this.fmtMonth,
    required this.fmtTnd,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <DataRow>[];
    final ids = byCar.keys.toList()..sort();

    for (final id in ids) {
      final months = byCar[id]!;
      for (final key in months.keys) {
        final parts = key.split('-');
        final ym = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        final data = months[key]!;
        final total = data.values.reduce((a, b) => a + b);
        rows.add(DataRow(cells: [
          DataCell(Text(getMatricule(id))),
          DataCell(Text(fmtMonth.format(ym))),
          ...allTypes.map((t) => DataCell(Text(fmtTnd(data[t] ?? 0)))),
          DataCell(Text(fmtTnd(total), style: const TextStyle(fontWeight: FontWeight.bold))),
        ]));
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          const DataColumn(label: Text('Matricule')),
          const DataColumn(label: Text('Mois')),
          ...allTypes.map((t) => DataColumn(label: Text(labelOf(t)))),
          const DataColumn(label: Text('Total')),
        ],
        rows: rows,
      ),
    );
  }
}
