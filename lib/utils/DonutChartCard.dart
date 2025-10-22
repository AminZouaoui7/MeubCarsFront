import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/Data/Models/TotalDepenses.dart';
import 'package:meubcars/utils/DonutChart.dart';

enum DepenseFilter { total, year, month }

class DonutChartCard extends StatefulWidget {
  const DonutChartCard({super.key});

  @override
  State<DonutChartCard> createState() => _DonutChartCardState();
}

class _DonutChartCardState extends State<DonutChartCard> {
  DepenseFilter _currentFilter = DepenseFilter.total;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  Future<TotalDepenses>? _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  // ===========================================================
  // 🔹 Charger selon filtre
  // ===========================================================
  Future<TotalDepenses> _loadData() async {
    String endpoint;

    switch (_currentFilter) {
      case DepenseFilter.year:
        endpoint = 'depenses/total/year/$_selectedYear';
        break;
      case DepenseFilter.month:
        endpoint = 'depenses/total/year/$_selectedYear/month/$_selectedMonth';
        break;
      default:
        endpoint = 'depenses/total';
    }

    final uri = Uri.parse('${EndPoint.baseUrl}$endpoint');
    final r = await http.get(uri);
    if (r.statusCode == 200) {
      return TotalDepenses.fromJson(jsonDecode(r.body));
    } else {
      throw Exception('Erreur ${r.statusCode}');
    }
  }

  // ===========================================================
  // 🔹 Titre dynamique
  // ===========================================================
  String _getTitle() {
    switch (_currentFilter) {
      case DepenseFilter.year:
        return "Dépenses – Année $_selectedYear";
      case DepenseFilter.month:
        return "Dépenses – ${_monthName(_selectedMonth)} $_selectedYear";
      default:
        return "Dépenses – Total global";
    }
  }

  String _monthName(int m) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[m - 1];
  }

  // ===========================================================
  // 🧠 UI
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TotalDepenses>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Text('Erreur : ${snap.error}', style: const TextStyle(color: Colors.redAccent));
        }

        final data = snap.data!;
        final entretien = data.vidange + data.pannes + data.autresEntretien;

        final rows = <_RowStat>[
          if (data.assurance > 0)
            _RowStat('Assurance', data.assurance, Icons.policy, const Color(0xFFE76F51)),
          if (data.vignette > 0)
            _RowStat('Vignette', data.vignette, Icons.receipt_long, const Color(0xFFF4A261)),
          if (data.carteGrise > 0)
            _RowStat('Carte grise', data.carteGrise, Icons.folder, const Color(0xFFE9C46A)),
          if (data.visiteTechnique > 0)
            _RowStat('Visite technique', data.visiteTechnique, Icons.build, const Color(0xFF2A9D8F)),
          if (data.taxe > 0)
            _RowStat('Taxe', data.taxe, Icons.request_quote, const Color(0xFF43AA8B)),
          if (entretien > 0)
            _RowStat('Entretien', entretien, Icons.car_repair, const Color(0xFF577590)),
          if (data.transport > 0)
            _RowStat('Transport', data.transport, Icons.local_shipping, const Color(0xFF277DA1)),
        ];

        return Card(
          margin: const EdgeInsets.all(10),
          color: const Color(0xFF121820),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Titre
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getTitle(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: () => setState(() => _future = _loadData()),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 🔘 Filtres (Total / Année / Mois)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildFilterButton('Total', DepenseFilter.total),
                    const SizedBox(width: 8),
                    _buildFilterButton('Année', DepenseFilter.year),
                    const SizedBox(width: 8),
                    _buildFilterButton('Mois', DepenseFilter.month),
                  ],
                ),

                const SizedBox(height: 12),

                // 🔽 Dropdowns dynamiques (année / mois)
                if (_currentFilter != DepenseFilter.total)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_currentFilter == DepenseFilter.year || _currentFilter == DepenseFilter.month)
                        DropdownButton<int>(
                          value: _selectedYear,
                          dropdownColor: const Color(0xFF1E2733),
                          style: const TextStyle(color: Colors.white),
                          items: List.generate(5, (i) {
                            final year = DateTime.now().year - i;
                            return DropdownMenuItem(value: year, child: Text('$year'));
                          }),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedYear = val;
                                _future = _loadData();
                              });
                            }
                          },
                        ),
                      const SizedBox(width: 12),
                      if (_currentFilter == DepenseFilter.month)
                        DropdownButton<int>(
                          value: _selectedMonth,
                          dropdownColor: const Color(0xFF1E2733),
                          style: const TextStyle(color: Colors.white),
                          items: List.generate(12, (i) {
                            return DropdownMenuItem(value: i + 1, child: Text(_monthName(i + 1)));
                          }),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedMonth = val;
                                _future = _loadData();
                              });
                            }
                          },
                        ),
                    ],
                  ),

                const SizedBox(height: 20),

                // Donut Chart
                Center(
                  child: SizedBox(height: 250, child: DonutChart(data: data)),
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),

                // Liste
                Column(
                  children: rows.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _StorageRow(stat: r),
                  )).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterButton(String label, DepenseFilter f) {
    final selected = _currentFilter == f;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? Colors.orange : const Color(0xFF1E2733),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => setState(() {
        _currentFilter = f;
        _future = _loadData();
      }),
      child: Text(label),
    );
  }
}

// ========================
// Helpers
// ========================
class _RowStat {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  const _RowStat(this.label, this.amount, this.icon, this.color);
}

class _StorageRow extends StatelessWidget {
  final _RowStat stat;
  const _StorageRow({super.key, required this.stat});

  String _fmt(double v) => '${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)} TND';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2733),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: stat.color.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(stat.icon, color: stat.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              stat.label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            _fmt(stat.amount),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
