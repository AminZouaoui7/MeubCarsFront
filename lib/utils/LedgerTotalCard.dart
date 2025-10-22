// lib/widgets/ledger_total_cards.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meubcars/Data/Dtos/DashboardApi.dart'; // ou PaiementsApi selon ton arborescence
import 'package:meubcars/Data/Models/paiment.dart'; // PaymentType, PaiementVM

typedef _FilterFn = bool Function(PaiementVM);

class _LedgerTotalCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final _FilterFn include;
  final int? voitureId;
  final DateTime? month; // par défaut: mois courant
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap; // ex: ouvrir historique

  const _LedgerTotalCard({
    super.key,
    required this.title,
    required this.icon,
    required this.include,
    this.voitureId,
    this.month,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  State<_LedgerTotalCard> createState() => _LedgerTotalCardState();
}

class _LedgerTotalCardState extends State<_LedgerTotalCard> {
  final _fmt =
  NumberFormat.currency(locale: 'fr_FR', symbol: 'TND', decimalDigits: 3);

  DateTime _month = DateTime.now(); // ✅ plus de "late" → toujours initialisé
  Future<double>? _future;

  @override
  void initState() {
    super.initState();
    final now = widget.month ?? DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _future = _fetchTotal();
  }

  Future<double> _fetchTotal() async {
    try {
      final api = await PaiementsApi.authed();

      final first = DateTime(_month.year, _month.month, 1);
      final nextMonth = DateTime(_month.year, _month.month + 1, 1);

      final list = await api.history(
        voitureId: widget.voitureId,
        from: first,
        to: nextMonth,
      );

      final filtered = list.where(widget.include);
      return filtered.fold<double>(0.0, (s, p) => s + p.montant);
    } catch (e) {
      debugPrint('⚠️ LedgerTotalCard fetch error: $e');
      return 0.0;
    }
  }

  void _prevMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1, 1);
      _future = _fetchTotal();
    });
  }

  void _nextMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1, 1);
      _future = _fetchTotal();
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR').format(_month);

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: widget.padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 En-tête (titre + navigation mois)
              Row(
                children: [
                  Icon(widget.icon, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    onPressed: _prevMonth,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    monthLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // 🔹 Montant
              FutureBuilder<double>(
                future: _future,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Calcul…'),
                      ],
                    );
                  }

                  if (snap.hasError) {
                    return Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Erreur : ${snap.error}',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _future = _fetchTotal()),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    );
                  }

                  final v = snap.data ?? 0.0;
                  return Text(
                    _fmt.format(v),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//
// ========= Cartes prêtes à l'emploi =========
//

// 1️⃣ Total global
class TotalPaiementsCard extends StatelessWidget {
  final int? voitureId;
  final DateTime? month;
  final VoidCallback? onTap;
  const TotalPaiementsCard({super.key, this.voitureId, this.month, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _LedgerTotalCard(
      title: 'Total des paiements (toutes catégories)',
      icon: Icons.summarize_outlined,
      voitureId: voitureId,
      month: month,
      onTap: onTap,
      include: (_) => true,
    );
  }
}

// 2️⃣ Administratif
class TotalAdministratifCard extends StatelessWidget {
  final int? voitureId;
  final DateTime? month;
  final VoidCallback? onTap;
  const TotalAdministratifCard(
      {super.key, this.voitureId, this.month, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _LedgerTotalCard(
      title: 'Total administratif',
      icon: Icons.account_balance_wallet_outlined,
      voitureId: voitureId,
      month: month,
      onTap: onTap,
      include: (p) =>
      p.type == PaymentType.Assurance ||
          p.type == PaymentType.CarteGrise ||
          p.type == PaymentType.Vignette ||
          p.type == PaymentType.VisiteTechnique,
    );
  }
}

// 3️⃣ Entretiens
class TotalEntretiensCard extends StatelessWidget {
  final int? voitureId;
  final DateTime? month;
  final VoidCallback? onTap;
  const TotalEntretiensCard(
      {super.key, this.voitureId, this.month, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _LedgerTotalCard(
      title: 'Total entretiens (vidange/panne)',
      icon: Icons.build,
      voitureId: voitureId,
      month: month,
      onTap: onTap,
      include: (p) => p.type == PaymentType.Entretien,
    );
  }
}
