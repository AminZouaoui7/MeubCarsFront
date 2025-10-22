import 'dart:io' show File; // dispo uniquement mobile/desktop
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

import 'package:meubcars/Data/Models/paiment.dart';

typedef OnViewPayment = void Function(PaymentItem item);

enum _Filter { all, overdue, dueSoon, thisMonth }

class PaiementsDuMoisCard extends StatefulWidget {
  final int? voitureId;
  final OnViewPayment? onView;
  final DateTime? initialMonth;
  final int dueDays;
  final VoidCallback? onOpenHistory;

  const PaiementsDuMoisCard({
    super.key,
    this.voitureId,
    this.onView,
    this.initialMonth,
    this.dueDays = 7,
    this.onOpenHistory,
  });

  @override
  State<PaiementsDuMoisCard> createState() => _PaiementsDuMoisCardState();
}

class _PaiementsDuMoisCardState extends State<PaiementsDuMoisCard> {
  DateTime? _month;
  _Filter _filter = _Filter.all;

  Future<PaymentSummary>? _future;
  PaiementsApi? _api;
  bool _initialized = false; // ✅ prevent premature build

  final NumberFormat _fmtCurrency =
  NumberFormat.currency(locale: 'fr_FR', symbol: 'TND', decimalDigits: 3);

  @override
  void initState() {
    super.initState();
    _month = DateTime(
      (widget.initialMonth ?? DateTime.now()).year,
      (widget.initialMonth ?? DateTime.now()).month,
      1,
    );
    _setup(); // async-safe init
  }

  Future<void> _setup() async {
    try {
      _api = await PaiementsApi.authed();
      _reload();
    } catch (e, st) {
      debugPrint('❌ PaiementsApi init error: $e\n$st');
    } finally {
      if (mounted) setState(() => _initialized = true);
    }
  }

  void _reload() {
    if (_api == null) return;
    setState(() {
      _future = _api!.fetchSummary(
        month: _month,
        voitureId: widget.voitureId,
        dueDays: widget.dueDays,
      );
    });
  }

  String _fmtMoney(num v) => _fmtCurrency.format(v).replaceAll('\u00A0', ' ');
  String _formatDate(DateTime? d) =>
      (d == null) ? '—' : DateFormat('dd/MM/yyyy').format(d);

  Color _stateColor(PaymentItem it, BuildContext ctx) {
    if (it.isOverdue) return Colors.redAccent;
    if (it.isDueSoon) return Colors.orangeAccent;
    if (it.datePaiement != null) return Colors.greenAccent;
    return Colors.blueAccent;
  }

  IconData _typeIcon(PaymentType t) {
    switch (t) {
      case PaymentType.Assurance:
        return Icons.verified_user;
      case PaymentType.CarteGrise:
        return Icons.credit_card;
      case PaymentType.Vignette:
        return Icons.sticky_note_2_rounded;
      case PaymentType.VisiteTechnique:
        return Icons.car_repair;
      case PaymentType.Entretien:
        return Icons.build;
      case PaymentType.Taxe:
        return Icons.receipt_rounded;
      case PaymentType.Autre:
        return Icons.help_outline;
    }
  }

  List<PaymentItem> _applyFilter(List<PaymentItem> items) {
    final actifs = items.where((i) => i.estActive).toList();
    switch (_filter) {
      case _Filter.all:
        return actifs;
      case _Filter.overdue:
        return actifs.where((i) => i.isOverdue).toList();
      case _Filter.dueSoon:
        return actifs.where((i) => i.isDueSoon && !i.isOverdue).toList();
      case _Filter.thisMonth:
        return actifs.where((i) => i.isDueThisMonth).toList();
    }
  }

  Future<void> _showPaymentFiche(PaymentItem it) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF17181B),
      builder: (_) => PaymentBottomSheet(
        item: it,
        onConfirm: (dateDebut, dateFin, datePaiement, nextDue, notes, pickedFile) async {
          if (_api != null) {
            try {
              await _api!.markAsPaidWithUpload(
                type: it.type,
                id: it.id,
                voitureId: it.voitureId,
                dateDebut: dateDebut,
                dateFin: dateFin,
                datePaiement: datePaiement,
                dateProchainPaiement: nextDue,
                notes: notes,
                montant: it.montant,
                pickedFile: pickedFile,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Paiement enregistré.')),
                );
                _reload();
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Échec: ${e.toString()}')),
                );
              }
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR').format(_month!);

    // ✅ Prevent build before initialization completes
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orangeAccent),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF17181B).withOpacity(.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.all(12),
      child: FutureBuilder<PaymentSummary>(
        future: _future,
        builder: (ctx, snap) {
          final badge = snap.hasData ? snap.data!.badgeCount : 0;
          final totalDue = snap.hasData ? snap.data!.totalDue : null;

          List<PaymentItem> filtered = [];
          double filteredTotal = 0;
          if (snap.hasData) {
            filtered = _applyFilter(snap.data!.items);
            for (final it in filtered) {
              if (it.montant != null) filteredTotal += it.montant!;
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Paiements du mois',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (badge > 0)
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('$badge',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  const Spacer(),
                  IconButton(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh, color: Colors.white54)),
                  const SizedBox(width: 4),
                  if (widget.onOpenHistory != null)
                    TextButton.icon(
                      onPressed: widget.onOpenHistory,
                      icon: const Icon(Icons.history,
                          color: Colors.orangeAccent),
                      label: const Text('Historique',
                          style: TextStyle(color: Colors.orangeAccent)),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              if (snap.hasData)
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('À traiter : ${totalDue ?? 0}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, color: Colors.white)),
                    if (badge > 0)
                      const Text('Alerte(s) en retard',
                          style: TextStyle(color: Colors.redAccent)),
                    if (filtered.isNotEmpty)
                      Text(
                          'Filtré : ${filtered.length} • ${_fmtMoney(filteredTotal)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.white70)),
                  ],
                ),

              const SizedBox(height: 8),

              if (snap.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snap.hasError)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Erreur: ${snap.error}',
                      style: const TextStyle(color: Colors.redAccent)),
                )
              else if (!snap.hasData || snap.data!.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Aucun paiement à afficher.',
                        style: TextStyle(color: Colors.white70)),
                  )
                else
                  Builder(
                    builder: (context) {
                      final items = filtered;
                      final maxListHeight =
                          MediaQuery.of(context).size.height * 0.5;
                      return ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxListHeight),
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                          const Divider(height: 8, color: Colors.white12),
                          itemBuilder: (ctx, i) {
                            final it = items[i];
                            final color = _stateColor(it, context);
                            final due = it.dueDate;
                            final subtitle =
                                'Échéance: ${_formatDate(due)}${it.montant != null ? '  •  Montant: ${_fmtMoney(it.montant!)}' : ''}';

                            return ListTile(
                              tileColor: Colors.white.withOpacity(0.02),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              leading: Icon(_typeIcon(it.type), color: color),
                              title: Text(
                                '${paymentTypeToLabel(it.type)}${it.libelle != null ? ' — ${it.libelle}' : ''}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(.92)),
                              ),
                              subtitle: Text(subtitle,
                                  style:
                                  const TextStyle(color: Colors.white70)),
                              onTap: () => _showPaymentFiche(it),
                              trailing: ElevatedButton.icon(
                                onPressed: () => _showPaymentFiche(it),
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                                label: const Text('Marquer payé'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  Colors.orangeAccent.withOpacity(.9),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  textStyle: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}

class PaymentBottomSheet extends StatefulWidget {
  final PaymentItem item;
  final Future<void> Function(
      DateTime dateDebut,
      DateTime dateFin,
      DateTime datePaiement,
      DateTime dateProchainPaiement,
      String? notes,
      PlatformFile? fichier,
      ) onConfirm;

  const PaymentBottomSheet({
    required this.item,
    required this.onConfirm,
    super.key,
  });

  @override
  State<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet> {
  DateTime? dateDebut;
  DateTime? dateFin;
  DateTime? datePaiement;
  DateTime? dateProchainPaiement;
  String? notes;
  PlatformFile? pickedFile;

  String _formatDate(DateTime? d) =>
      d == null ? "—" : DateFormat('dd/MM/yyyy').format(d);

  @override
  void initState() {
    super.initState();
    dateDebut = widget.item.dateDebut ?? DateTime.now();
    dateFin = widget.item.dateFin ?? DateTime.now().add(const Duration(days: 365));
    datePaiement = DateTime.now();
    dateProchainPaiement =
        widget.item.dateProchainPaiement ?? DateTime.now().add(const Duration(days: 365));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Marquer comme payé",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),

            _buildDateRow("Date début", dateDebut, (d) => setState(() => dateDebut = d)),
            _buildDateRow("Date fin", dateFin, (d) => setState(() => dateFin = d)),
            _buildDateRow("Date paiement", datePaiement, (d) => setState(() => datePaiement = d)),
            _buildDateRow("Prochaine échéance", dateProchainPaiement,
                    (d) => setState(() => dateProchainPaiement = d)),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text(
                    pickedFile != null ? pickedFile!.name : "Aucun justificatif",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final file = await PaiementsApi.pickOneFile(
                      allowedExt: ['pdf', 'jpg', 'jpeg', 'png'],
                    );
                    if (file != null) {
                      setState(() => pickedFile = file);
                    }
                  },
                  icon: const Icon(Icons.upload_file, color: Colors.orangeAccent),
                  label: const Text("Choisir fichier",
                      style: TextStyle(color: Colors.orangeAccent)),
                ),
              ],
            ),

            const SizedBox(height: 8),

            TextField(
              decoration: const InputDecoration(
                  labelText: "Notes", labelStyle: TextStyle(color: Colors.white70)),
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => notes = v),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annuler", style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    if (dateDebut == null ||
                        dateFin == null ||
                        datePaiement == null ||
                        dateProchainPaiement == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Toutes les dates doivent être choisies.")),
                      );
                      return;
                    }

                    Navigator.pop(context);
                    await widget.onConfirm(
                      dateDebut!,
                      dateFin!,
                      datePaiement!,
                      dateProchainPaiement!,
                      notes,
                      pickedFile,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black),
                  child: const Text("Confirmer"),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRow(String label, DateTime? value, Function(DateTime) onPicked) {
    return Row(
      children: [
        Text("$label: ", style: const TextStyle(color: Colors.white)),
        const SizedBox(width: 8),
        Text(_formatDate(value), style: const TextStyle(color: Colors.white70)),
        const Spacer(),
        TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) onPicked(picked);
          },
          child: const Text("Choisir", style: TextStyle(color: Colors.orangeAccent)),
        ),
      ],
    );
  }
}
