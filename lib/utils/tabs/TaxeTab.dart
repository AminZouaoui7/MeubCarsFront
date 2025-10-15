import 'package:flutter/material.dart';
import 'package:meubcars/utils/tabs/GenericDocTab.dart';

class TaxeTab extends StatelessWidget {
  final int voitureId;
  const TaxeTab({super.key, required this.voitureId});

  @override
  Widget build(BuildContext context) {
    return GenericDocTab(
      voitureId: voitureId,
      endpoint: "Taxes/by-voiture",
      title: "Taxe",
      icon: Icons.receipt_long_outlined,
    );
  }
}
