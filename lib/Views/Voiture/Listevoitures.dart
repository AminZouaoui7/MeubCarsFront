// lib/Views/Voiture/Listevoitures.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:meubcars/Data/Models/paiment.dart';
import 'package:meubcars/Views/superadmin/docs.dart';

import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/core/cache/CacheHelper.dart';

import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/background.dart';

// 👇 NEW: imports to load the cached user for the AppBar
import 'package:meubcars/Data/Models/user_model.dart';
import 'package:meubcars/Data/repositories/auth_repository.dart';
import 'package:meubcars/Data/remote/auth_remote.dart';

class Listevoitures extends StatefulWidget {
  const Listevoitures({super.key});

  @override
  State<Listevoitures> createState() => _ListevoituresState();
}

class _ListevoituresState extends State<Listevoitures> {
  final _searchCtrl = TextEditingController();

  // HTTP client
  final Dio _dio = Dio(BaseOptions(
    baseUrl: EndPoint.baseUrl, // ex: http://10.0.2.2:7178/api
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  // 👇 NEW: repo + future to get cached user (for AppBarWithMenu)
  final AuthRepository _authRepo = AuthRepository(AuthRemote());
  Future<UserModel?>? _userF;

  // State
  bool _loading = true;
  String? _error;
  List<_Car> _all = [];
  List<_Car> _filtered = [];

  // ==== Filtre Société ====
  static const String _socAll = '__ALL__';
  static const String _socNone = '__NONE__';
  String _societeFilter = _socAll; // valeur sélectionnée

  // ====== Entretien (Panne / Vidange) ======
  // ⚠️ Les libellés doivent correspondre aux noms exacts de l'enum C# MaintenanceType
  static const List<String> _maintenanceTypes = ['Vidange', 'Panne'];

  Future<int>? _nbPaiementsF;

  @override
  void initState() {
    super.initState();
    _userF = _authRepo.getCachedUser();
    _nbPaiementsF = fetchNbPaiementsEnRetard(); // 👈 Future stable (comme Home)
    _searchCtrl.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }


  Future<int> fetchNbPaiementsEnRetard() async {
    try {
      final api = await PaiementsApi.authed();
      final summary = await api.fetchSummary(); // ton endpoint summary
      return summary.badgeCount; // nombre de paiements en retard
    } catch (e) {
      debugPrint('Erreur chargement paiements: $e');
      return 0;
    }
  }

  // ===== API =====
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await CacheHelper.getData(key: 'token');
      final headers = <String, String>{};
      if (token != null && token.toString().isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final res = await _dio.get('Voitures', options: Options(headers: headers));
      if (res.statusCode != 200) {
        throw Exception('Erreur serveur (${res.statusCode})');
      }

      final data = (res.data as List?) ?? const [];
      final cars = data.map((e) => _Car.fromJson(e as Map<String, dynamic>)).toList();

      setState(() {
        _all = cars;
        final names = _societeNames();
        if (_societeFilter != _socAll &&
            _societeFilter != _socNone &&
            !names.map((e) => e.toLowerCase()).contains(_societeFilter.toLowerCase())) {
          _societeFilter = _socAll;
        }
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

  Future<void> _deleteCar(_Car car) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer la voiture ${car.matricule} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final token = await CacheHelper.getData(key: 'token');
      final headers = <String, String>{};
      if (token != null && token.toString().isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      await _dio.delete('Voitures/${car.id}', options: Options(headers: headers));

      setState(() {
        _all.removeWhere((c) => c.id == car.id);
        _applyFilter();
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Voiture ${car.matricule} supprimée.')));
      }
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(e.response?.data?.toString() ?? e.message ?? 'Erreur réseau'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text('Erreur: $e')));
    }
  }

  // ===== Entretien helpers =====
  Future<DateTime?> _pickDate(BuildContext context, {DateTime? initial}) async {
    final now = DateTime.now();
    final first = DateTime(now.year - 5);
    final last = DateTime(now.year + 5);
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: first,
      lastDate: last,
      helpText: 'Date de l’opération',
    );
  }

  Future<void> _openEntretienForm(_Car car) async {
    final formKey = GlobalKey<FormState>();
    String type = _maintenanceTypes.first; // par défaut: 'Vidange'
    final coutCtrl = TextEditingController();
    DateTime dateOp = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text('Nouvel entretien — ${car.matricule}'),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: type,
                        items: _maintenanceTypes
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) => setState(() => type = v ?? type),
                        decoration: const InputDecoration(labelText: 'Type (Vidange / Panne)'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: coutCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Coût (ex: 120.50)'),
                        validator: (v) {
                          final txt = (v ?? '').trim().replaceAll(',', '.');
                          if (txt.isEmpty) return 'Coût obligatoire';
                          final d = double.tryParse(txt);
                          if (d == null || d < 0) return 'Montant invalide';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Date'),
                              child: Text(
                                '${dateOp.year.toString().padLeft(4, '0')}-'
                                    '${dateOp.month.toString().padLeft(2, '0')}-'
                                    '${dateOp.day.toString().padLeft(2, '0')}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: () async {
                              final d = await _pickDate(context, initial: dateOp);
                              if (d != null) setState(() => dateOp = d);
                            },
                            child: const Icon(Icons.date_range),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer'),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    try {
                      final token = await CacheHelper.getData(key: 'token');
                      final headers = <String, String>{};
                      if (token != null && token.toString().isNotEmpty) {
                        headers['Authorization'] = 'Bearer $token';
                      }

                      final body = {
                        "voitureId": car.id,
                        "type": type, // enum en texte grâce à JsonStringEnumConverter côté .NET
                        "cout": double.parse(coutCtrl.text.trim().replaceAll(',', '.')),
                        // ISO 8601; on fixe 12:00 pour éviter les surprises de fuseau
                        "dateOperation": DateTime(
                          dateOp.year, dateOp.month, dateOp.day, 12, 0, 0,
                        ).toIso8601String(),
                      };

                      final res = await _dio.post(
                        'Entretiens',
                        data: body,
                        options: Options(headers: headers),
                      );

                      if (res.statusCode != 201 && res.statusCode != 200) {
                        throw Exception('Échec (${res.statusCode})');
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Entretien enregistré.')),
                        );
                      }
                      Navigator.pop(ctx, true);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(backgroundColor: Colors.red, content: Text('Erreur: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true) {
      // Si besoin de rafraîchir quelque chose ici.
      // await _load();
    }
  }

  // ===== UI helpers =====

  List<String> _societeNames() {
    final s = <String>{};
    for (final c in _all) {
      final n = c.societeNom?.trim();
      if (n != null && n.isNotEmpty) s.add(n);
    }
    final list = s.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
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

  void _closeDrawerIfOpen() {
    final s = Scaffold.maybeOf(context);
    if (s?.isDrawerOpen ?? false) Navigator.of(context).pop();
  }

  void _go(String route) async {
    // ✅ Ferme proprement le Drawer si ouvert
    final s = Scaffold.maybeOf(context);
    if (s?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return; // 👈 évite de recharger la même page inutilement

    // ✅ Navigation fluide : on remplace la page actuelle
    // pour éviter d'empiler des routes et garder le menu cohérent
    await Navigator.of(context).pushReplacementNamed(route);


    // 🔁 facultatif : si tu veux rafraîchir la liste après retour
    if (mounted) setState(() => _load());
  }



  @override
  Widget build(BuildContext context) {
    final routeNow =
        ModalRoute.of(context)?.settings.name ?? AppRoutes.voituresList;

    final socNames = _societeNames();
    final dropdownItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: _socAll, child: Text('Toutes les sociétés')),
      const DropdownMenuItem(value: _socNone, child: Text('Sans société')),
      ...socNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
    ];

    return FutureBuilder<UserModel?>(
      future: _userF,
      builder: (_, snapUser) {
        if (snapUser.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Colors.white70)),
          );
        }

        if (!snapUser.hasData || snapUser.data == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    "Impossible de charger l'utilisateur",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () =>
                        setState(() => _userF = _authRepo.getCachedUser()),
                    icon: const Icon(Icons.refresh),
                    label: const Text("Réessayer"),
                  ),
                ],
              ),
            ),
          );
        }

        final user = snapUser.data!;

        // ✅ nouvelle logique : future statique pour le badge
        return FutureBuilder<int>(
          future: _nbPaiementsF, // ⚠️ défini une seule fois dans initState()
          builder: (_, snapBadge) {
            final nbBadge = snapBadge.data ?? 0;

            final sections = AppMenu.buildDefaultSections(
            );

            return Scaffold(
              key: const ValueKey('ListeVoituresScaffold'),
              backgroundColor: Colors.transparent,
              appBar: AppBarWithMenu(
                title: 'Liste des voitures',
                onNavigate: _go,
                sections: sections,
                activeRoute: routeNow,
                currentUser: user,
              ),
              drawer: AppSideMenu(
                key: const ValueKey('AppSideMenu'), // ✅ état persistant
                activeRoute: routeNow,
                sections: sections,
                onNavigate: _go,
              ),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  const BrandBackground(),
                  SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // ===== Toolbar =====
                              Row(
                                children: [
                                  // 🔍 Recherche
                                  Expanded(
                                    child: TextField(
                                      controller: _searchCtrl,
                                      style:
                                      const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.search,
                                            color: Colors.white70),
                                        hintText:
                                        'Rechercher (matricule, marque, modèle...)',
                                        hintStyle: const TextStyle(
                                            color: Colors.white54),
                                        filled: true,
                                        fillColor: const Color(0xFF1A1A1E),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.kBg3),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.kBg3),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.kOrange,
                                              width: 1.4),
                                        ),
                                        contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // 🏢 Filtre société
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        minWidth: 230, maxWidth: 320),
                                    child: DropdownButtonFormField<String>(
                                      value: _societeFilter,
                                      items: dropdownItems,
                                      onChanged: (v) {
                                        if (v == null) return;
                                        setState(() => _societeFilter = v);
                                        _applyFilter();
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Société',
                                        filled: true,
                                        fillColor: const Color(0xFF1A1A1E),
                                        labelStyle: const TextStyle(
                                            color: AppColors.onDark60),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.kBg3),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: AppColors.kOrange,
                                              width: 1.4),
                                        ),
                                        contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 12),
                                      ),
                                      dropdownColor: const Color(0xFF1A1A1E),
                                      iconEnabledColor: Colors.white70,
                                      style:
                                      const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // ➕ Ajouter voiture
                                  FilledButton.icon(
                                    onPressed: () => _go(AppRoutes.voituresAdd),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Ajouter'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.kOrange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // ===== Liste =====
                              Expanded(
                                child: Card(
                                  color: const Color(0xFF121214).withOpacity(.55),
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: const BorderSide(
                                        color: AppColors.kBg3),
                                  ),
                                  child: RefreshIndicator(
                                    onRefresh: _load,
                                    child: _loading
                                        ? const Center(
                                        child: CircularProgressIndicator(
                                            color: Colors.white70))
                                        : (_error != null)
                                        ? ListView(
                                      children: [
                                        const SizedBox(height: 80),
                                        Center(
                                          child: Text(
                                            _error!,
                                            style: const TextStyle(
                                                color:
                                                Colors.redAccent),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Center(
                                          child: TextButton.icon(
                                            onPressed: _load,
                                            icon: const Icon(
                                                Icons.refresh),
                                            label:
                                            const Text('Réessayer'),
                                          ),
                                        ),
                                      ],
                                    )
                                        : (_filtered.isEmpty)
                                        ? const Center(
                                      child: Text(
                                        'Aucune voiture',
                                        style: TextStyle(
                                            color: Colors.white70),
                                      ),
                                    )
                                        : ListView.separated(
                                      padding:
                                      const EdgeInsets.all(8),
                                      itemCount:
                                      _filtered.length,
                                      separatorBuilder: (_, __) =>
                                      const Divider(
                                          color:
                                          Colors.white12,
                                          height: 1),
                                      itemBuilder: (context, i) {
                                        final c = _filtered[i];
                                        return ListTile(
                                          onTap: () {
                                            Navigator.of(context).pushNamed(
                                              AppRoutes.voitureDetails,
                                              arguments: c.id,
                                            );
                                          },
                                          leading: Icon(
                                            Icons.directions_car_filled,
                                            color: c.active == false ? Colors.redAccent : Colors.white70, // 🚨 rouge si inactive
                                          ),
                                          title: Text(
                                            '${c.marque} ${c.modele}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              decoration: c.active == false ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                            subtitle: Text(
                                              'Matricule: ${c.matricule}'
                                                  '  •  ${(c.occupee == "Libre" || c.occupee.isEmpty) ? "Libre" : "️ ${c.occupee}"}'
                                                  '${c.active == false ? '  •  🚨 EN PANNE' : ''}',
                                              style: TextStyle(
                                                color: c.active == false ? Colors.redAccent : Colors.white70,
                                                fontWeight: c.active == false ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          trailing: Wrap(
                                            spacing: 6,
                                            children: [
                                              if (c.active == false)
                                                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                                              IconButton(
                                                tooltip: 'Voir documents',
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => DocumentationVoiturePage(
                                                        voitureId: c.id,
                                                        voitureNom: '${c.marque} ${c.modele}',
                                                      ),
                                                    ),
                                                  );
                                                },
                                                icon: const Icon(Icons.folder_open, color: Colors.lightGreenAccent),
                                              ),
                                              IconButton(
                                                tooltip: 'Entretien (panne / vidange)',
                                                onPressed: () => _openEntretienForm(c),
                                                icon: const Icon(Icons.build_circle_outlined, color: Colors.white70),
                                              ),
                                              IconButton(
                                                tooltip: 'Supprimer',
                                                onPressed: () => _deleteCar(c),
                                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )],
              ),
            );
          },
        );
      },
    );
  }
}

// ===== Modèle léger pour la liste =====
class _Car {
  final int id;
  final String matricule;
  final String marque;
  final String modele;
  final int? annee;
  final String? carburant;
  final int? kilometrage;
  final bool active;
  final String? societeNom;
  final String? numInterne;

  /// 🆕 Nom du chauffeur si occupée, sinon "Libre"
  final String occupee;

  _Car({
    required this.id,
    required this.matricule,
    required this.marque,
    required this.modele,
    this.annee,
    this.carburant,
    this.kilometrage,
    this.active = true,
    this.societeNom,
    this.numInterne,
    this.occupee = "Libre",
  });

  factory _Car.fromJson(Map<String, dynamic> j) {
    // Récupération du nom de la société
    final soc = j['societeRef'];
    final socName = (soc is Map)
        ? (soc['nom'] ?? soc['raisonSociale'] ?? soc['name'] ?? '').toString()
        : null;

    // Conversion sûre en int
    int? _toInt(dynamic v) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '');
    }

    // Conversion sûre en bool
    bool _toBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v == 1;
      final s = v?.toString().toLowerCase();
      return s == 'true' || s == '1';
    }

    // ✅ Construction de l'objet
    return _Car(
      id: _toInt(j['id']) ?? 0,
      matricule: (j['matricule'] ?? '').toString(),
      marque: (j['marque'] ?? '').toString(),
      modele: (j['modele'] ?? '').toString(),
      annee: _toInt(j['annee']),
      carburant: (j['carburant']?.toString().isEmpty ?? true)
          ? null
          : j['carburant'].toString(),
      kilometrage: _toInt(j['kilometrage']),
      active: _toBool(j['active']),
      societeNom: (socName != null && socName.isNotEmpty) ? socName : null,
      numInterne: j['numInterne']?.toString(),
      occupee: (j['occupee'] != null && j['occupee'].toString().trim().isNotEmpty)
          ? j['occupee'].toString().trim()
          : "Libre",
    );
  }

  /// 🔍 Index de recherche textuelle
  String get searchIndex => [
    matricule,
    marque,
    modele,
    annee?.toString() ?? '',
    carburant ?? '',
    societeNom ?? '',
    numInterne ?? '',
    occupee
  ].join(' ').toLowerCase();
}
