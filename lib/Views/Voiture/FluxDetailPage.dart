// lib/Views/Voiture/FluxDetail.dart
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:meubcars/Core/Cache/cacheHelper.dart';
import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/background.dart';

class FluxDetailPage extends StatefulWidget {
  final int? fluxId;
  const FluxDetailPage({super.key, this.fluxId});

  @override
  State<FluxDetailPage> createState() => _FluxDetailPageState();
}

class _FluxDetailPageState extends State<FluxDetailPage>
    with SingleTickerProviderStateMixin {
  final Dio _dio = Dio(BaseOptions(baseUrl: EndPoint.baseUrl));

  // ===== Couleurs (orange comme la photo) =====
  static const Color _brandOrange = Color(0xFFFF7A00); // orange vif
  static const Color _roadGray = Color(0xFF2A2A2C);

  Future<Map<String, String>> _authHeaders() async {
    final token = await CacheHelper.getData(key: 'token');
    final h = <String, String>{'Accept': 'application/json'};
    if (token != null && token.toString().isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  bool _loading = false;
  Map<String, dynamic>? _detail; // DTO du flux
  String? _vehiculeLabel;        // "Marque Modèle · Matricule"
  String? _chauffeurNom;         // si le DTO ne le renvoie pas
  String? _etat;                 // EnCours / Planifie / Termine / Annule

  // === Animation ===
  late final AnimationController _driveCtl;
  static const Duration _driveLoop = Duration(seconds: 8); // Changed from 5 to 8 seconds

  @override
  void initState() {
    super.initState();
    _driveCtl = AnimationController(
      vsync: this,
      duration: _driveLoop,
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(); // boucle continue, on gère l'arrêt selon l'état
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _driveCtl.dispose();
    super.dispose();
  }

  int? _readIdFromArgs() {
    if (widget.fluxId != null) return widget.fluxId;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) return args;
    if (args is Map && args['id'] != null) {
      final v = args['id'];
      if (v is int) return v;
      return int.tryParse(v.toString());
    }
    return null;
  }

  String _asString(dynamic v) => (v ?? '').toString();

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }

  Color _etatColor(String? etat) {
    final e = (etat ?? '').toLowerCase();
    if (e.contains('cours')) return _brandOrange;
    if (e.contains('plan')) return Colors.amber;
    if (e.contains('term')) return Colors.blueAccent;
    if (e.contains('ann')) return Colors.redAccent;
    return Colors.white70;
  }

  bool _isEtatEnCours(String? e) {
    final s = (e ?? '').toLowerCase();
    return s.contains('cours');
  }

  bool _isEtatTermine(String? e) {
    final s = (e ?? '').toLowerCase();
    return s.contains('term');
  }

  // === Image fourgon (orange) ===
  static const String _vanId = '3c06a6eb-e895-4e7b-971d-2c11dba223c0';

  String _vanImageUrlFromId(String id) {
    // ⚠️ adapte le chemin à ton backend si nécessaire
    return '${EndPoint.baseUrl}/Files/$id';
  }

  Widget _vanImage({double size = 88}) {
    final url = _vanImageUrlFromId(_vanId);
    return Container(
      // halo orange doux
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: _brandOrange.withOpacity(.35),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.local_shipping, size: size, color: _brandOrange),
      ),
    );
  }

  Future<void> _load() async {
    final id = _readIdFromArgs();
    if (id == null) {
      _show('Identifiant du flux manquant.');
      return;
    }

    setState(() => _loading = true);
    try {
      final headers = await _authHeaders();

      // 1) Flux
      final r =
      await _dio.get('FluxTransports/$id', options: Options(headers: headers));
      final dto = (r.data as Map).cast<String, dynamic>();
      _detail = dto;

      // Etat
      _etat = _asString(
          dto['etat'].toString().isNotEmpty ? dto['etat'] : dto['Etat']);

      // 2) Chauffeur
      _chauffeurNom = _asString(dto['chauffeurNom'].toString().isNotEmpty
          ? dto['chauffeurNom']
          : dto['ChauffeurNom']);
      final chauffeurId =
          _asInt(dto['chauffeurId']) ?? _asInt(dto['ChauffeurId']);

      // 3) Véhicule
      final voitureId = _asInt(dto['voitureId']) ?? _asInt(dto['VoitureId']);
      if (voitureId != null && voitureId > 0) {
        try {
          final v = await _dio.get('Voitures/$voitureId',
              options: Options(headers: headers));
          final vm = (v.data as Map).cast<String, dynamic>();
          final label =
          '${_asString(vm['marque'])} ${_asString(vm['modele'])} · ${_asString(vm['matricule'])}'
              .trim();
          _vehiculeLabel = label.isEmpty ? 'Voiture #$voitureId' : label;
        } catch (_) {/* ignore */}
      }

      // Animation selon état
      if (_isEtatEnCours(_etat)) {
        if (!_driveCtl.isAnimating) _driveCtl.repeat();
      } else {
        if (_driveCtl.isAnimating) _driveCtl.stop();
        _driveCtl.value = _isEtatTermine(_etat) ? 1.0 : 0.0;
      }

      setState(() {});
    } on DioException catch (e) {
      _show(e.response?.data?.toString() ?? e.message ?? 'Erreur réseau');
    } catch (e) {
      _show(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final routeNow =
        ModalRoute.of(context)?.settings.name ?? AppRoutes.voituresFluxDetail;

    final sections = AppMenu.buildDefaultSections(

      hasPaiementAlerts: () => true,
    );

    final d = _detail;
    final dateFlux = d != null
        ? DateTime.tryParse(_asString(d['dateFlux'] ?? d['DateFlux'])) ??
        DateTime.now()
        : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBarWithMenu(
        title: 'Détail du flux',
        onNavigate: (r) => Navigator.of(context).pushReplacementNamed(r),
        sections: sections,
        activeRoute: routeNow,
      ),
      drawer: AppSideMenu(
        activeRoute: routeNow,
        sections: sections,
        onNavigate: (r) => Navigator.of(context).pushReplacementNamed(r),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const BrandBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    color: const Color(0xFF121214).withOpacity(.55),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppColors.kBg3),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_loading) const LinearProgressIndicator(minHeight: 2),
                          Row(
                            children: [
                              const Text(
                                'Détail du flux',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              if (_etat != null && _etat!.trim().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _etatColor(_etat).withOpacity(.18),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color:
                                        _etatColor(_etat).withOpacity(.35)),
                                  ),
                                  child: Text(_etat!,
                                      style:
                                      const TextStyle(color: Colors.white)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 16),

                          // ====== CARTE TRAJET AMÉLIORÉE ======
                          if (d != null) ...[
                            _journeyCard(d, _etat, dateFlux),
                            const SizedBox(height: 16),
                          ],

                          if (d == null)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Aucune donnée',
                                  style: TextStyle(color: Colors.white70)),
                            )
                          else ...[
                            _row('Date & heure',
                                dateFlux != null ? _fmtDate(dateFlux) : '—'),
                            _row('Véhicule', _vehiculeLabel ?? '—'),
                            _row(
                                'Départ',
                                _asString(d['depart'] ?? d['Depart']).isEmpty
                                    ? '—'
                                    : _asString(d['depart'] ?? d['Depart'])),
                            _row(
                                'Destination',
                                _asString(d['destination'] ?? d['Destination'])
                                    .isEmpty
                                    ? '—'
                                    : _asString(
                                    d['destination'] ?? d['Destination'])),
                            _row('Chauffeur',
                                (_chauffeurNom ?? '').isEmpty ? '—' : _chauffeurNom!),
                            _row(
                                'Objet',
                                _asString(d['objet'] ?? d['Objet']).isEmpty
                                    ? '—'
                                    : _asString(d['objet'] ?? d['Objet'])),
                            _row(
                                'Kilomètres parcourus',
                                _asString(d['kilometresParcourus'] ??
                                    d['KilometresParcourus'])
                                    .isEmpty
                                    ? '—'
                                    : _asString(d['kilometresParcourus'] ??
                                    d['KilometresParcourus'])),
                            _row(
                                'Coût (TND)',
                                _asString(d['cout'] ?? d['Cout']).isEmpty
                                    ? '—'
                                    : _asString(d['cout'] ?? d['Cout'])),
                            _row(
                                'Notes',
                                _asString(d['notes'] ?? d['Notes']).isEmpty
                                    ? '—'
                                    : _asString(d['notes'] ?? d['Notes'])),
                          ],

                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Retour'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: AppColors.kBg3),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Carte trajet animée ----------
  Widget _journeyCard(
      Map<String, dynamic> d, String? etat, DateTime? dateFlux) {
    final depart = _asString(d['depart'] ?? d['Depart']);
    final destination = _asString(d['destination'] ?? d['Destination']);

    final isEnCours = _isEtatEnCours(etat);
    final isTermine = _isEtatTermine(etat);

    return Card(
      color: const Color(0xFF121214).withOpacity(.65),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.kBg3),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bandeau
            Row(
              children: [
                Icon(
                  isEnCours ? Icons.local_shipping : Icons.flag,
                  color: isEnCours ? _brandOrange : Colors.blueAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEnCours
                        ? 'En route vers $destination'
                        : (isTermine
                        ? 'Arrivé à destination'
                        : (etat ?? '')),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (dateFlux != null)
                  Text(
                    _fmtDate(dateFlux),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Route + animations
            SizedBox(
              height: 150,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final roadY = 88.0;
                  final margin = 14.0;
                  final startX = margin + 12;
                  final endX = w - margin - 12;

                  // 0..1 du controller
                  final tRaw = _driveCtl.value;
                  final t = isEnCours ? tRaw : (isTermine ? 1.0 : 0.0);
                  final x = startX + (endX - startX) * t;

                  // bobbing + légère rotation
                  final bob = isEnCours ? math.sin(tRaw * math.pi * 2) * 3.5 : 0.0;
                  final tilt = isEnCours ? math.sin(tRaw * math.pi * 2) * 0.06 : 0.0;

                  return AnimatedBuilder(
                    animation: _driveCtl,
                    builder: (_, __) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Labels départ/destination
                          Positioned(
                            left: margin,
                            top: 6,
                            child: Text(
                              depart.isEmpty ? 'Départ' : depart,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          Positioned(
                            right: margin,
                            top: 6,
                            child: Text(
                              destination.isEmpty ? 'Destination' : destination,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),

                          // ROUTE (fond)
                          Positioned(
                            left: startX,
                            right: w - endX,
                            top: roadY,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: _roadGray,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white10),
                              ),
                            ),
                          ),

                          // Ligne centrale "animée" (effet défilement)
                          Positioned(
                            left: startX,
                            right: w - endX,
                            top: roadY + 2.5,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    // décalage basé sur tRaw pour simuler
                                    // des pointillés qui avancent
                                    stops: [
                                      (tRaw * 0.8) % 1.0,
                                      (tRaw * 0.8 + .08) % 1.0,
                                      (tRaw * 0.8 + .28) % 1.0,
                                      (tRaw * 0.8 + .36) % 1.0,
                                      (tRaw * 0.8 + .56) % 1.0,
                                      (tRaw * 0.8 + .64) % 1.0,
                                      (tRaw * 0.8 + .84) % 1.0,
                                      (tRaw * 0.8 + .92) % 1.0,
                                    ]..sort(),
                                    colors: const [
                                      Colors.transparent,
                                      Colors.white30,
                                      Colors.transparent,
                                      Colors.white30,
                                      Colors.transparent,
                                      Colors.white30,
                                      Colors.transparent,
                                      Colors.white30,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Point de départ
                          Positioned(
                            left: startX - 6,
                            top: roadY - 7,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _brandOrange,
                                shape: BoxShape.circle,
                                border:
                                Border.all(color: Colors.black26, width: 1),
                              ),
                            ),
                          ),

                          // Drapeau arrivée
                          Positioned(
                            left: endX - 6,
                            top: roadY - 20,
                            child: Column(
                              children: [
                                Icon(Icons.flag,
                                    size: 18,
                                    color: isTermine
                                        ? Colors.blueAccent
                                        : Colors.white38),
                                const SizedBox(height: 6),
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: isTermine
                                        ? Colors.blueAccent
                                        : Colors.white30,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.black26, width: 1),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Ombre sous le van (effet mouvement)
                          Positioned(
                            left: x - 36,
                            top: roadY + 10,
                            child: Container(
                              width: 72,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(.25),
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),

                          // VAN avec bobbing + tilt + halo orange
                          Positioned(
                            left: x - 44,
                            top: roadY - 70 + bob,
                            child: Transform.rotate(
                              angle: tilt,
                              child: _vanImage(size: 88),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Lignes d'info ----------
  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 210,
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
