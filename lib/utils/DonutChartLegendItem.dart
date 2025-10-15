import 'package:flutter/material.dart';

class DonutChartLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const DonutChartLegendItem({
    Key? key,
    required this.color,
    required this.label,
  }): super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
