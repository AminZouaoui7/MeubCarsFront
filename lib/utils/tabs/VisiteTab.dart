import 'package:flutter/material.dart';
import 'package:meubcars/utils/tabs/GenericDocTab.dart';

class VisiteTab extends StatelessWidget {
  final int voitureId;
  const VisiteTab({super.key, required this.voitureId});

  @override
  Widget build(BuildContext context) {
    return GenericDocTab(
      voitureId: voitureId,
      endpoint: "Visites/by-voiture",
      title: "Visite technique",
      icon: Icons.car_repair_outlined,
    );
  }
}
