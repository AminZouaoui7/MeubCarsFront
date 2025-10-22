import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meubcars/Data/Models/TotalDepenses.dart';
import 'package:meubcars/Data/Remote/depenses_api.dart';

class DepenseTotalGlobalCard extends StatefulWidget {
  const DepenseTotalGlobalCard({
    super.key,
    this.dense = false,
    this.padding = const EdgeInsets.all(16),
    this.onOpenHistory,
  });

  /// Police un peu plus petite si tu veux l’intégrer dans une grille serrée
  final bool dense;

  /// Personnalise le padding si besoin
  final EdgeInsetsGeometry padding;

  /// Action pour ouvrir l’historique (routeur parent)
  final VoidCallback? onOpenHistory;

  @override
  State<DepenseTotalGlobalCard> createState() => _DepenseTotalGlobalCardState();
}

class _DepenseTotalGlobalCardState extends State<DepenseTotalGlobalCard> {
  final _api = DepensesApi();
  Future<TotalDepenses>? _future;

  // Format “1 234,567 TND” — fallback si la locale n’est pas chargée
  final NumberFormat _fmtCurrency =
  NumberFormat.currency(locale: 'fr_FR', symbol: 'TND', decimalDigits: 3);

  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _api.fetchTotalGlobal();
      _lastRefresh = DateTime.now();
    });
  }

  String _fmt(num v) {
    try {
      return _fmtCurrency.format(v).replaceAll('\u00A0', ' ');
    } catch (_) {
      // fallback ultra-safe
      return '${v.toStringAsFixed(3)} TND';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleStyle = TextStyle(
      fontSize: widget.dense ? 15 : 16,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : Colors.black87,
    );

    final valueStyle = TextStyle(
      fontSize: widget.dense ? 22 : 30,
      fontWeight: FontWeight.w800,
      letterSpacing: .3,
      color: isDark ? Colors.white : Colors.black,
    );

    final subStyle = theme.textTheme.bodySmall?.copyWith(
      color: isDark ? Colors.white70 : Colors.black54,
    );

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: widget.padding,
        child: FutureBuilder<TotalDepenses>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return _LoadingRow(
                label: widget.dense ? 'Chargement…' : 'Chargement du total…',
                compact: widget.dense,
              );
            }

            if (snap.hasError) {
              return _ErrorRow(
                message: 'Erreur: ${snap.error}',
                onRetry: _reload,
              );
            }

            final total = snap.data?.total ?? 0.0;

            return Semantics(
              container: true,
              label: 'Total des dépenses pour toutes les voitures',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(Icons.summarize_outlined,
                          size: 20, color: isDark ? Colors.white : Colors.black87),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Total des dépenses (toutes voitures)',
                          style: titleStyle,
                        ),
                      ),
                      IconButton(
                        onPressed: _reload,
                        tooltip: 'Rafraîchir',
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Valeur
                  Text(_fmt(total), style: valueStyle),

                  // Footer actions
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_lastRefresh != null)
                        Text(
                          'Mis à jour : ${DateFormat('dd/MM/yyyy HH:mm').format(_lastRefresh!)}',
                          style: subStyle,
                        ),
                      const Spacer(),
                      if (widget.onOpenHistory != null)
                        TextButton.icon(
                          onPressed: widget.onOpenHistory,
                          icon: const Icon(Icons.history),
                          label: const Text('Historique'),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({this.label = 'Chargement…', this.compact = false});
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: compact ? 18 : 22,
          height: compact ? 18 : 22,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorRow({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.redAccent),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
      ],
    );
  }
}
