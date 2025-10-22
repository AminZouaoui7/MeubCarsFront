import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:meubcars/Data/Models/TotalDepenses.dart';

class DonutChart extends StatefulWidget {
  final TotalDepenses data;
  const DonutChart({super.key, required this.data});

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();

    try {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      );

      _animation = CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeOutCubic,
      );

      _controller!.forward();
    } catch (e) {
      debugPrint('⚠️ DonutChart init error: $e');
      _controller = null;
      _animation = const AlwaysStoppedAnimation(1.0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = _animation ?? const AlwaysStoppedAnimation(1.0);

    final data = widget.data;
    final total = data.total;
    if (total <= 0) {
      return const Center(
        child: Text("Aucune donnée", style: TextStyle(color: Colors.white70)),
      );
    }

    final entretien = data.vidange + data.pannes + data.autresEntretien;

    final values = {
      'Assurance': data.assurance,
      'Vignette': data.vignette,
      'Carte grise': data.carteGrise,
      'Visite technique': data.visiteTechnique,
      'Taxe': data.taxe,
      'Entretien': entretien,
      'Transport': data.transport,
    };

    final customColors = {
      'Assurance': const Color(0xFFE76F51),
      'Vignette': const Color(0xFFF4A261),
      'Carte grise': const Color(0xFFE9C46A),
      'Visite technique': const Color(0xFF2A9D8F),
      'Taxe': const Color(0xFF43AA8B),
      'Entretien': const Color(0xFF577590),
      'Transport': const Color(0xFF277DA1),
    };

    final activeEntries = values.entries.where((e) => e.value > 0).toList();

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = animation.value;

        final sections = activeEntries.map((e) {
          final pct = (e.value / total) * 100 * progress;
          return PieChartSectionData(
            value: e.value * progress,
            color: customColors[e.key],
            radius: 65,
            showTitle: true,
            title: '${pct.toStringAsFixed(1)}%',
            titlePositionPercentageOffset: 0.7,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          );
        }).toList();

        return AspectRatio(
          aspectRatio: 1.2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 70,
                  sectionsSpace: 2,
                  borderData: FlBorderData(show: false),
                  startDegreeOffset: -90,
                ),
              ),
              FadeTransition(
                opacity: animation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      total.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Total TND',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
