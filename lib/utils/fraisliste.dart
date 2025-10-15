// lib/Views/Entretien/frais_voiture_page.dart  (ex-EntretiensPage)
// => Page avec 2 onglets: Entretiens & Taxes

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/Core/Cache/cacheHelper.dart';

// ================= Modèles / helpers =================
enum MaintenanceTypeDart { vidange, panne }
MaintenanceTypeDart? parseType(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'vidange':
      return MaintenanceTypeDart.vidange;
    case 'panne':
      return MaintenanceTypeDart.panne;
    default:
      return null;
  }
}
String typeToText(MaintenanceTypeDart t) =>
    t == MaintenanceTypeDart.vidange ? 'Vidange' : 'Panne';

class EntretienModel {
  final int id;
  final int voitureId;
  final MaintenanceTypeDart? type;
  final double cout;
  final DateTime dateOperation;

  EntretienModel({
    required this.id,
    required this.voitureId,
    required this.type,
    required this.cout,
    required this.dateOperation,
  });

  factory EntretienModel.fromJson(Map<String, dynamic> j) {
    int _toInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
    double _toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0;
    }

    return EntretienModel(
      id: _toInt(j['id']),
      voitureId: _toInt(j['voitureId']),
      type: parseType(j['type']?.toString()),
      cout: _toDouble(j['cout']),
      dateOperation:
      DateTime.tryParse(j['dateOperation']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class TaxeModel {
  final int id;
  final int voitureId;
  final String libelle;
  final double montant;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final DateTime? datePaiement;
  final DateTime? dateProchainPaiement;

  TaxeModel({
    required this.id,
    required this.voitureId,
    required this.libelle,
    required this.montant,
    this.dateDebut,
    this.dateFin,
    this.datePaiement,
    this.dateProchainPaiement,
  });

  factory TaxeModel.fromJson(Map<String, dynamic> j) {
    int _toInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
    double _toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0;
    }

    DateTime? _toDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return TaxeModel(
      id: _toInt(j['id']),
      voitureId: _toInt(j['voitureId']),
      libelle: (j['libelle'] ?? '').toString(),
      montant: _toDouble(j['montant']),
      dateDebut: _toDate(j['dateDebut']),
      dateFin: _toDate(j['dateFin']),
      datePaiement: _toDate(j['datePaiement']),
      dateProchainPaiement: _toDate(j['dateProchainPaiement']),
    );
  }

  Map<String, dynamic> toCreateBody() => {
    'voitureId': voitureId,
    'libelle': libelle,
    'montant': montant,
    'dateDebut': dateDebut?.toIso8601String(),
    'dateFin': dateFin?.toIso8601String(),
    'datePaiement': datePaiement?.toIso8601String(),
    'dateProchainPaiement': dateProchainPaiement?.toIso8601String(),
  };
}

// ================= PAGE =================
class EntretiensPage extends StatefulWidget {
  final int voitureId;
  final String? matricule;

  const EntretiensPage({super.key, required this.voitureId, this.matricule});

  @override
  State<EntretiensPage> createState() => _EntretiensPageState();
}

class _EntretiensPageState extends State<EntretiensPage>
    with SingleTickerProviderStateMixin {
  late final Dio _dio = Dio(BaseOptions(
    baseUrl: EndPoint.baseUrl, // ex: http://10.0.2.2:7178/api
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  // Tabs
  late final TabController _tab;

  // Entretiens state
  bool _loadingEnt = true;
  String? _errorEnt;
  List<EntretienModel> _allEnt = [];

  // Taxes state
  bool _loadingTax = true;
  String? _errorTax;
  List<TaxeModel> _allTax = [];

  // Filtres entretiens
  MaintenanceTypeDart? _filterType; // null=tous
  DateTime? _dateFrom;
  DateTime? _dateTo;

  final _fmtDate = DateFormat('dd/MM/yyyy');
  final _fmtMoney =
  NumberFormat.currency(locale: 'fr_FR', symbol: 'DH', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadEnt();
    _loadTax();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await CacheHelper.getData(key: 'token');
    final h = <String, String>{};
    if (token != null && token.toString().isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  // ===== ENTRETIENS =====
  Future<void> _loadEnt() async {
    setState(() {
      _loadingEnt = true;
      _errorEnt = null;
    });
    try {
      final headers = await _authHeaders();
      final r = await _dio.get(
        'Entretiens',
        queryParameters: {'voitureId': widget.voitureId},
        options: Options(headers: headers),
      );
      final data = (r.data as List?) ?? const [];
      setState(() {
        _allEnt = data
            .map((e) => EntretienModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _loadingEnt = false;
      });
    } on DioException catch (e) {
      setState(() {
        _errorEnt = e.response?.data?.toString() ?? e.message ?? 'Erreur réseau';
        _loadingEnt = false;
      });
    } catch (e) {
      setState(() {
        _errorEnt = e.toString();
        _loadingEnt = false;
      });
    }
  }

  List<EntretienModel> get _filteredEnt {
    return _allEnt.where((e) {
      if (_filterType != null && e.type != _filterType) return false;
      if (_dateFrom != null &&
          e.dateOperation
              .isBefore(DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day))) {
        return false;
      }
      if (_dateTo != null &&
          e.dateOperation.isAfter(DateTime(
              _dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59))) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.dateOperation.compareTo(a.dateOperation));
  }

  double get _totalAllEnt =>
      _filteredEnt.fold(0, (p, e) => p + e.cout);
  double get _totalVidange =>
      _filteredEnt.where((e) => e.type == MaintenanceTypeDart.vidange).fold(0, (p, e) => p + e.cout);
  double get _totalPanne =>
      _filteredEnt.where((e) => e.type == MaintenanceTypeDart.panne).fold(0, (p, e) => p + e.cout);

  Future<void> _deleteEnt(int id) async {
    try {
      final headers = await _authHeaders();
      await _dio.delete('Entretiens/$id', options: Options(headers: headers));
      setState(() => _allEnt.removeWhere((x) => x.id == id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Entretien supprimé')));
      }
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: Colors.red,
            content: Text(e.message ?? 'Erreur suppression')),
      );
    }
  }

  Future<void> _addEntDialog() async {
    final formKey = GlobalKey<FormState>();
    MaintenanceTypeDart? type = MaintenanceTypeDart.vidange;
    final coutCtrl = TextEditingController();
    DateTime dateOp = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nouvel entretien ${widget.matricule ?? ''}'.trim()),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<MaintenanceTypeDart>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                        value: MaintenanceTypeDart.vidange,
                        child: Text('Vidange')),
                    DropdownMenuItem(
                        value: MaintenanceTypeDart.panne, child: Text('Panne')),
                  ],
                  onChanged: (v) => type = v,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: coutCtrl,
                  decoration:
                  const InputDecoration(labelText: 'Coût (DH)'),
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final x =
                    double.tryParse((v ?? '').replaceAll(',', '.'));
                    return (x == null || x <= 0) ? 'Montant invalide' : null;
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('Date: ${_fmtDate.format(dateOp)}')),
                    TextButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: dateOp,
                          firstDate: DateTime(2015),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) {
                          setState(() => dateOp =
                              DateTime(d.year, d.month, d.day));
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: const Text('Choisir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final headers = await _authHeaders();
                final body = {
                  'voitureId': widget.voitureId,
                  'type': typeToText(type!),
                  'cout': double.parse(
                      coutCtrl.text.trim().replaceAll(',', '.')),
                  'dateOperation': DateTime(dateOp.year, dateOp.month, dateOp.day, 12)
                      .toIso8601String(),
                };
                final res = await _dio.post('Entretiens',
                    data: body, options: Options(headers: headers));
                if (res.statusCode == 201) {
                  Navigator.pop(ctx);
                  await _loadEnt();
                } else {
                  throw Exception('Erreur ${res.statusCode}');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      backgroundColor: Colors.red,
                      content: Text(e.toString())),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 3),
      initialDateRange: (_dateFrom != null && _dateTo != null)
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : DateTimeRange(
          start: DateTime(now.year, now.month, 1), end: now),
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
    }
  }

  void _clearDateRange() =>
      setState(() {
        _dateFrom = null;
        _dateTo = null;
      });

  // ===== TAXES =====
  Future<void> _loadTax() async {
    setState(() {
      _loadingTax = true;
      _errorTax = null;
    });
    try {
      final headers = await _authHeaders();
      final r = await _dio.get(
        'Taxes',
        queryParameters: {'voitureId': widget.voitureId},
        options: Options(headers: headers),
      );
      final data = (r.data as List?) ?? const [];
      setState(() {
        _allTax = data
            .map((e) => TaxeModel.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) {
            final da = a.dateFin ?? a.dateProchainPaiement ?? a.dateDebut ?? a.datePaiement ?? DateTime(1900);
            final db = b.dateFin ?? b.dateProchainPaiement ?? b.dateDebut ?? b.datePaiement ?? DateTime(1900);
            return db.compareTo(da);
          });
        _loadingTax = false;
      });
    } on DioException catch (e) {
      setState(() {
        _errorTax = e.response?.data?.toString() ?? e.message ?? 'Erreur réseau';
        _loadingTax = false;
      });
    } catch (e) {
      setState(() {
        _errorTax = e.toString();
        _loadingTax = false;
      });
    }
  }

  double get _totalTax =>
      _allTax.fold(0.0, (p, t) => p + t.montant);

  Future<void> _deleteTax(int id) async {
    try {
      final headers = await _authHeaders();
      await _dio.delete('Taxes/$id', options: Options(headers: headers));
      setState(() => _allTax.removeWhere((x) => x.id == id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Taxe supprimée')));
      }
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: Colors.red,
            content: Text(e.message ?? 'Erreur suppression')),
      );
    }
  }

  Future<void> _addTaxDialog() async {
    final formKey = GlobalKey<FormState>();
    final libelleCtrl = TextEditingController();
    final montantCtrl = TextEditingController();
    DateTime? dDebut;
    DateTime? dFin;
    DateTime? dPaiement;
    DateTime? dNext;

    Future<void> pick(String title, void Function(DateTime) set) async {
      final d = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2015),
        lastDate: DateTime(2100),
      );
      if (d != null) set(DateTime(d.year, d.month, d.day));
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nouvelle taxe ${widget.matricule ?? ''}'.trim()),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: libelleCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Libellé', hintText: 'Ex: Taxe municipale 2025'),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: montantCtrl,
                    decoration:
                    const InputDecoration(labelText: 'Montant (DH)'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: (v) {
                      final x =
                      double.tryParse((v ?? '').replaceAll(',', '.'));
                      return (x == null || x <= 0)
                          ? 'Montant invalide'
                          : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Début: ${dDebut == null ? '-' : _fmtDate.format(dDebut!)}'),
                      ),
                      TextButton.icon(
                        onPressed: () => pick('Date début', (val) { setState(() => dDebut = val); }),
                        icon: const Icon(Icons.event),
                        label: const Text('Choisir'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Fin: ${dFin == null ? '-' : _fmtDate.format(dFin!)}'),
                      ),
                      TextButton.icon(
                        onPressed: () => pick('Date fin', (val) { setState(() => dFin = val); }),
                        icon: const Icon(Icons.event),
                        label: const Text('Choisir'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Paiement: ${dPaiement == null ? '-' : _fmtDate.format(dPaiement!)}'),
                      ),
                      TextButton.icon(
                        onPressed: () => pick('Date paiement', (val) { setState(() => dPaiement = val); }),
                        icon: const Icon(Icons.event),
                        label: const Text('Choisir'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Prochain: ${dNext == null ? '-' : _fmtDate.format(dNext!)}'),
                      ),
                      TextButton.icon(
                        onPressed: () => pick('Prochain paiement', (val) { setState(() => dNext = val); }),
                        icon: const Icon(Icons.event),
                        label: const Text('Choisir'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final headers = await _authHeaders();
                final body = {
                  'voitureId': widget.voitureId,
                  'libelle': libelleCtrl.text.trim(),
                  'montant': double.parse(
                      montantCtrl.text.trim().replaceAll(',', '.')),
                  'dateDebut': dDebut?.toIso8601String(),
                  'dateFin': dFin?.toIso8601String(),
                  'datePaiement': dPaiement?.toIso8601String(),
                  'dateProchainPaiement': dNext?.toIso8601String(),
                };
                final res = await _dio.post('Taxes',
                    data: body, options: Options(headers: headers));
                if (res.statusCode == 201) {
                  Navigator.pop(ctx);
                  await _loadTax();
                } else {
                  throw Exception('Erreur ${res.statusCode}');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      backgroundColor: Colors.red,
                      content: Text(e.toString())),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          'Frais ${widget.matricule != null ? '· ${widget.matricule}' : ''}',
        ),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Entretiens', icon: Icon(Icons.build)),
            Tab(text: 'Taxes', icon: Icon(Icons.receipt_rounded)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              if (_tab.index == 0) {
                await _loadEnt();
              } else {
                await _loadTax();
              }
            },
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tab.index == 0) {
            _addEntDialog();
          } else {
            _addTaxDialog();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ===== Onglet ENTRETIENS =====
          _buildEntretiensTab(),
          // ===== Onglet TAXES =====
          _buildTaxesTab(),
        ],
      ),
    );
  }

  // === UI Entretiens
  Widget _buildEntretiensTab() {
    if (_loadingEnt) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorEnt != null) {
      return Center(
          child:
          Text(_errorEnt!, style: const TextStyle(color: Colors.redAccent)));
    }

    final items = _filteredEnt;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Résumé (totaux)
          LayoutBuilder(
            builder: (_, c) {
              final w = c.maxWidth;
              final col = w >= 1100
                  ? 4
                  : w >= 740
                  ? 3
                  : w >= 520
                  ? 2
                  : 1;
              final gap = 12.0;
              final cardW = (w - (col - 1) * gap) / col;
              Widget wrapCard(String title, String value, IconData icon) {
                return SizedBox(
                  width: cardW,
                  child: Card(
                    color: const Color(0xFF1A1A1E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.orange.withOpacity(.2),
                            child: Icon(icon, color: Colors.orange),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style:
                                    const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 4),
                                Text(_fmtMoney.format(double.tryParse(value) ?? 0) == 'DH 0,00'
                                    ? value
                                    : value,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  wrapCard('Total', _fmtMoney.format(_totalAllEnt),
                      Icons.summarize),
                  wrapCard('Vidange', _fmtMoney.format(_totalVidange),
                      Icons.oil_barrel),
                  wrapCard('Panne', _fmtMoney.format(_totalPanne),
                      Icons.build),
                  wrapCard('Entrées', '${items.length}', Icons.list_alt),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Filtres
          Card(
            color: const Color(0xFF1A1A1E),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // type
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Tous'),
                        selected: _filterType == null,
                        onSelected: (_) => setState(() => _filterType = null),
                      ),
                      ChoiceChip(
                        label: const Text('Vidange'),
                        selected:
                        _filterType == MaintenanceTypeDart.vidange,
                        onSelected: (_) => setState(() =>
                        _filterType = MaintenanceTypeDart.vidange),
                      ),
                      ChoiceChip(
                        label: const Text('Panne'),
                        selected: _filterType == MaintenanceTypeDart.panne,
                        onSelected: (_) => setState(
                                () => _filterType = MaintenanceTypeDart.panne),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // date range
                  if (_dateFrom != null && _dateTo != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${_fmtDate.format(_dateFrom!)} → ${_fmtDate.format(_dateTo!)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range),
                    label: const Text('Période'),
                  ),
                  const SizedBox(width: 8),
                  if (_dateFrom != null || _dateTo != null)
                    IconButton(
                      tooltip: 'Réinitialiser',
                      onPressed: _clearDateRange,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Liste
          Expanded(
            child: items.isEmpty
                ? const Center(
                child: Text('Aucun entretien',
                    style: TextStyle(color: Colors.white70)))
                : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final e = items[i];
                final isVid = e.type == MaintenanceTypeDart.vidange;
                final color = isVid ? Colors.orange : Colors.blueGrey;
                return Dismissible(
                  key: ValueKey('entretien_${e.id}'),
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child:
                    const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        title: const Text('Supprimer'),
                        content: const Text(
                            'Supprimer cet entretien ?'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(dctx, false),
                              child: const Text('Annuler')),
                          FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dctx, true),
                              child: const Text('Supprimer')),
                        ],
                      ),
                    ) ??
                        false;
                  },
                  onDismissed: (_) => _deleteEnt(e.id),
                  child: Card(
                    color: const Color(0xFF1A1A1E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(.2),
                        child: Icon(
                            isVid ? Icons.oil_barrel : Icons.build,
                            color: color),
                      ),
                      title: Text(
                        '${typeToText(e.type ?? MaintenanceTypeDart.vidange)} • ${_fmtMoney.format(e.cout)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(_fmtDate.format(e.dateOperation),
                          style: const TextStyle(color: Colors.white70)),
                      trailing: IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (dctx) => AlertDialog(
                              title: const Text('Supprimer'),
                              content: const Text(
                                  'Supprimer cet entretien ?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(
                                            dctx, false),
                                    child:
                                    const Text('Annuler')),
                                FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(
                                            dctx, true),
                                    child:
                                    const Text('Supprimer')),
                              ],
                            ),
                          ) ??
                              false;
                          if (ok) _deleteEnt(e.id);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // === UI Taxes
  Widget _buildTaxesTab() {
    if (_loadingTax) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorTax != null) {
      return Center(
          child:
          Text(_errorTax!, style: const TextStyle(color: Colors.redAccent)));
    }

    final items = _allTax;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Résumé
          Card(
            color: const Color(0xFF1A1A1E),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.withOpacity(.2),
                child: const Icon(Icons.receipt_long, color: Colors.orange),
              ),
              title: const Text('Total Taxes',
                  style: TextStyle(color: Colors.white70)),
              subtitle: Text(_fmtMoney.format(_totalTax),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              trailing: Text('Éléments: ${items.length}',
                  style: const TextStyle(color: Colors.white70)),
            ),
          ),
          const SizedBox(height: 12),

          // Liste
          Expanded(
            child: items.isEmpty
                ? const Center(
                child: Text('Aucune taxe',
                    style: TextStyle(color: Colors.white70)))
                : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final t = items[i];
                final chip = <Widget>[];
                if (t.dateDebut != null) {
                  chip.add(_chip('Début: ${_fmtDate.format(t.dateDebut!)}'));
                }
                if (t.dateFin != null) {
                  chip.add(_chip('Fin: ${_fmtDate.format(t.dateFin!)}'));
                }
                if (t.datePaiement != null) {
                  chip.add(_chip('Payé: ${_fmtDate.format(t.datePaiement!)}'));
                }
                if (t.dateProchainPaiement != null) {
                  chip.add(_chip('Prochain: ${_fmtDate.format(t.dateProchainPaiement!)}'));
                }

                return Dismissible(
                  key: ValueKey('taxe_${t.id}'),
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child:
                    const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        title: const Text('Supprimer'),
                        content: const Text('Supprimer cette taxe ?'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(dctx, false),
                              child: const Text('Annuler')),
                          FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dctx, true),
                              child: const Text('Supprimer')),
                        ],
                      ),
                    ) ??
                        false;
                  },
                  onDismissed: (_) => _deleteTax(t.id),
                  child: Card(
                    color: const Color(0xFF1A1A1E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                        const Color(0xFFFEB434).withOpacity(.2),
                        child: const Icon(Icons.receipt_rounded,
                            color: Color(0xFFFEB434)),
                      ),
                      title: Text(
                        '${t.libelle.isEmpty ? 'Taxe' : t.libelle} • ${_fmtMoney.format(t.montant)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                      subtitle: chip.isEmpty
                          ? const Text('—',
                          style:
                          TextStyle(color: Colors.white70))
                          : Wrap(spacing: 6, runSpacing: -8, children: chip),
                      trailing: IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (dctx) => AlertDialog(
                              title: const Text('Supprimer'),
                              content:
                              const Text('Supprimer cette taxe ?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(
                                            dctx, false),
                                    child:
                                    const Text('Annuler')),
                                FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(
                                            dctx, true),
                                    child:
                                    const Text('Supprimer')),
                              ],
                            ),
                          ) ??
                              false;
                          if (ok) _deleteTax(t.id);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) => Chip(
    label: Text(text),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}
