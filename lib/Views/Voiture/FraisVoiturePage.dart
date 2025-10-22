// lib/Views/Entretien/frais_voiture_page.dart
import 'dart:convert' as convert;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/core/cache/CacheHelper.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/fraisliste.dart';

// 👇 NEW: bring the model so AppBarWithMenu can show the user's name/avatar
import 'package:meubcars/Data/Models/user_model.dart';

class FraisVoiturePage extends StatefulWidget {
  const FraisVoiturePage({super.key});

  @override
  State<FraisVoiturePage> createState() => _FraisVoiturePageState();
}

class _FraisVoiturePageState extends State<FraisVoiturePage> {
  // HTTP
  final Dio _dio = Dio(BaseOptions(
    baseUrl: EndPoint.baseUrl, // ex: http://10.0.2.2:7178/api
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  // State
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  List<_Car> _all = [];
  List<_Car> _filtered = [];

  // filtre société
  static const String _socAll = '__ALL__';
  static const String _socNone = '__NONE__';
  String _societeFilter = _socAll;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ========= NEW: current user loader (same logic as other pages) =========
  Future<UserModel?> _getCurrentUser() async {
    dynamic raw;

    for (final key in ['user', 'currentUser', 'profile']) {
      raw = await CacheHelper.getData(key: key);
      if (raw != null) break;
    }

    try {
      if (raw is Map) {
        return UserModel.fromJson(Map<String, dynamic>.from(raw));
      }
      if (raw is String && raw.trim().isNotEmpty) {
        final decoded = convert.jsonDecode(raw);
        if (decoded is Map) {
          return UserModel.fromJson(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (_) {}

    final name = await CacheHelper.getData(key: 'nomComplet') ??
        await CacheHelper.getData(key: 'fullName') ??
        await CacheHelper.getData(key: 'name');

    final email = await CacheHelper.getData(key: 'email') ??
        await CacheHelper.getData(key: 'Email');

    final avatar = await CacheHelper.getData(key: 'avatarUrl') ??
        await CacheHelper.getData(key: 'avatar');

    final id = await CacheHelper.getData(key: 'userId') ??
        await CacheHelper.getData(key: 'id');

    if (name != null && name.toString().trim().isNotEmpty) {
      return UserModel.fromJson({
        'id': (id is int) ? id : int.tryParse('${id ?? 0}') ?? 0,
        'nomComplet': name.toString(),
        'email': email?.toString(),
        'avatarUrl': avatar?.toString(),
      });
    }
    return null;
  }
  // =======================================================================

  Future<Map<String, String>> _authHeaders() async {
    final token = await CacheHelper.getData(key: 'token');
    final h = <String, String>{};
    if (token != null && token.toString().isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final headers = await _authHeaders();
      final res = await _dio.get('Voitures', options: Options(headers: headers));
      if (res.statusCode != 200) {
        throw Exception('Erreur serveur (${res.statusCode})');
      }
      final data = (res.data as List?) ?? const [];
      final cars = data.map((e) => _Car.fromJson(e as Map<String, dynamic>)).toList();

      setState(() {
        _all = cars;
        _applyFilter();
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?.toString() ?? e.message ?? 'Erreur réseau';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();

    bool matchSociete(_Car c) {
      if (_societeFilter == _socAll) return true;
      if (_societeFilter == _socNone) {
        return (c.societeNom == null || c.societeNom!.trim().isEmpty);
      }
      return (c.societeNom ?? '').toLowerCase() == _societeFilter.toLowerCase();
    }

    setState(() {
      _filtered = _all.where((c) {
        final searchOk = q.isEmpty ? true : c.searchIndex.contains(q);
        final socOk = matchSociete(c);
        return searchOk && socOk;
      }).toList();
    });
  }


  // simple navigator for the AppBarWithMenu
  void _navigate(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1000;

    return FutureBuilder<UserModel?>(
      future: _getCurrentUser(),
      builder: (context, snap) {
        final user = snap.data; // may be null; AppBar shows "Utilisateur" then

        return Scaffold(
          appBar: AppBarWithMenu(
            title: 'Frais de Voitures',
            onNavigate: _navigate,
            currentUser: user, // ✅ real name/initials/avatar in the app bar
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ===== Toolbar =====
                  Row(
                    children: [
                      // Search
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Rechercher (matricule, marque, modèle...)',
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // (optional) add société filter UI here if needed
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ===== Contenu =====
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : (_error != null)
                        ? _ErrorBox(message: _error!, onRetry: _load)
                        : (_filtered.isEmpty)
                        ? const Center(child: Text('Aucune voiture trouvée'))
                        : LayoutBuilder(
                      builder: (_, c) {
                        final cross = isWide ? 2 : 1;
                        final ratio = isWide ? 3.6 : 2.8;
                        return GridView.builder(
                          itemCount: _filtered.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cross,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: ratio,
                          ),
                          itemBuilder: (_, i) {
                            final car = _filtered[i];
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            return Card(
                              color: isDark ? const Color(0xFF1A1A1E) : Colors.white,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: isDark
                                          ? const Color(0xFF2A2A32)
                                          : const Color(0xFFEFEFEF),
                                      child: Icon(
                                        Icons.directions_car_filled,
                                        color: isDark
                                            ? const Color(0xFFFFB38A)
                                            : const Color(0xFF8A4D2B),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Texts
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${car.marque} ${car.modele}  ·  ${car.annee ?? '-'}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isDark ? Colors.white : Colors.black,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              height: 1.1,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Matricule: ${car.matricule}'
                                                '${car.societeNom != null && car.societeNom!.isNotEmpty ? '  •  ${car.societeNom}' : ''}'
                                                '${car.carburant != null ? '  •  ${car.carburant}' : ''}'
                                                '${car.kilometrage != null ? '  •  ${car.kilometrage} km' : ''}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isDark ? Colors.white70 : Colors.black54,
                                              fontSize: 13.5,
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // CTA

                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ===== Modèle léger =====
class _Car {
  final int id;
  final String matricule;
  final String marque;
  final String modele;
  final int? annee;
  final String? carburant;
  final int? kilometrage;
  final String? societeNom;

  _Car({
    required this.id,
    required this.matricule,
    required this.marque,
    required this.modele,
    this.annee,
    this.carburant,
    this.kilometrage,
    this.societeNom,
  });

  factory _Car.fromJson(Map<String, dynamic> j) {
    int? _toInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '');
    final soc = j['societeRef'];
    final socName = (soc is Map)
        ? (soc['nom'] ?? soc['raisonSociale'] ?? soc['name'] ?? '').toString()
        : null;

    return _Car(
      id: _toInt(j['id']) ?? 0,
      matricule: (j['matricule'] ?? '').toString(),
      marque: (j['marque'] ?? '').toString(),
      modele: (j['modele'] ?? '').toString(),
      annee: _toInt(j['annee']),
      carburant: (j['carburant']?.toString().isEmpty ?? true) ? null : j['carburant'].toString(),
      kilometrage: _toInt(j['kilometrage']),
      societeNom: (socName != null && socName.isNotEmpty) ? socName : null,
    );
  }

  String get searchIndex =>
      '$matricule $marque $modele ${annee ?? ''} ${carburant ?? ''} ${societeNom ?? ''}'.toLowerCase();
}

// ===== petit widget d'erreur =====
class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(message, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 8),
        TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
      ],
    );
  }
}
