import 'package:flutter/material.dart';
import 'package:meubcars/utils/tabs/GenericDocTab.dart';

class AssuranceTab extends StatelessWidget {
  final int voitureId;
  const AssuranceTab({super.key, required this.voitureId});

  @override
  Widget build(BuildContext context) {
    return GenericDocTab(
      voitureId: voitureId,
      endpoint: "Assurances/by-voiture",
      title: "Assurance",
      icon: Icons.verified_user_outlined,
    );
  }
}
