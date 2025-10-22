import 'package:flutter/material.dart';
import 'package:meubcars/utils/tabs/GenericDocTab.dart';

class VignetteTab extends StatelessWidget {
  final int voitureId;
  const VignetteTab({super.key, required this.voitureId});

  @override
  Widget build(BuildContext context) {
    return GenericDocTab(
      voitureId: voitureId,
      endpoint: "Vignettes/by-voiture",
      title: "Vignette",
      icon: Icons.local_activity_outlined,
    );
  }
}
