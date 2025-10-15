class TotalDepenses {
  final double assurance;
  final double vignette;
  final double carteGrise;
  final double visiteTechnique;
  final double taxe;
  final double vidange;
  final double pannes;
  final double transport; // ✅ nouveau champ
  final double autresEntretien; // si tu l’utilises encore côté front

  TotalDepenses({
    required this.assurance,
    required this.vignette,
    required this.carteGrise,
    required this.visiteTechnique,
    required this.taxe,
    required this.vidange,
    required this.pannes,
    required this.transport,
    this.autresEntretien = 0,
  });

  double get total =>
      assurance +
          vignette +
          carteGrise +
          visiteTechnique +
          taxe +
          vidange +
          pannes +
          transport +
          autresEntretien;

  factory TotalDepenses.fromJson(Map<String, dynamic> json) {
    double _toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return TotalDepenses(
      assurance: _toDouble(json['assurance']),
      vignette: _toDouble(json['vignette']),
      carteGrise: _toDouble(json['carteGrise']),
      visiteTechnique: _toDouble(json['visiteTechnique']),
      taxe: _toDouble(json['taxe']),
      vidange: _toDouble(json['vidange']),
      pannes: _toDouble(json['pannes']),
      transport: _toDouble(json['transport']), // ✅ ajouté ici
      autresEntretien: _toDouble(json['autresEntretien']),
    );
  }

  Map<String, dynamic> toJson() => {
    'assurance': assurance,
    'vignette': vignette,
    'carteGrise': carteGrise,
    'visiteTechnique': visiteTechnique,
    'taxe': taxe,
    'vidange': vidange,
    'pannes': pannes,
    'transport': transport, // ✅ ajouté ici aussi
    'autresEntretien': autresEntretien,
    'total': total,
  };
}
