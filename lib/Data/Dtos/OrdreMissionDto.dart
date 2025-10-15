class OrdreMissionDto {
  final int voitureId;
  final int chauffeurId;
  final String lieuDepart;
  final String destination;
  final String objet;
  final String? client;
  final DateTime dateDepart;
  final DateTime dateRetourPrevue;
  final int? kmDepart;
  final String? notes;

  OrdreMissionDto({
    required this.voitureId,
    required this.chauffeurId,
    required this.lieuDepart,
    required this.destination,
    required this.objet,
    this.client,
    required this.dateDepart,
    required this.dateRetourPrevue,
    this.kmDepart,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'voitureId': voitureId,
    'chauffeurId': chauffeurId,
    'lieuDepart': lieuDepart,
    'destination': destination,
    'objet': objet,
    'client': client,
    'dateDepart': dateDepart.toIso8601String(),
    'dateRetourPrevue': dateRetourPrevue.toIso8601String(),
    'kmDepart': kmDepart,
    'notes': notes,
  };
}
