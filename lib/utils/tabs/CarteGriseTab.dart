import 'package:flutter/material.dart';
import 'package:meubcars/utils/tabs/GenericDocTab.dart';

class CarteGriseTab extends StatelessWidget {
  final int voitureId;
  const CarteGriseTab({super.key, required this.voitureId});

  @override
  Widget build(BuildContext context) {
    return GenericDocTab(
      voitureId: voitureId,
      endpoint: "CartesGrises/by-voiture",
      title: "Carte grise",
      icon: Icons.assignment_outlined,
    );
  }
}
