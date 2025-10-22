import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:meubcars/core/cache/cacheHelper.dart';
import 'package:meubcars/Data/Models/user_model.dart';
import 'package:meubcars/Data/remote/auth_remote.dart';
import 'package:meubcars/Data/repositories/auth_repository.dart';
import 'package:meubcars/Views/chaffeurs/Ajouterchauffeur.dart';
import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/background.dart';

class ListeChauffeursPage extends StatefulWidget {
  const ListeChauffeursPage({super.key});

  @override
  State<ListeChauffeursPage> createState() => _ListeChauffeursPageState();
}

class _ListeChauffeursPageState extends State<ListeChauffeursPage> {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: EndPoint.baseUrl,
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
  ));

  Future<Map<String, String>> _authHeaders() async {
    final token = await CacheHelper.getData(key: 'token');
    final h = <String, String>{'Accept': 'application/json'};
    if (token != null && token.toString().isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  final AuthRepository _authRepo = AuthRepository(AuthRemote());
  Future<UserModel?>? _userF;

  bool _loading = false;
  String? _error;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _chauffeurs = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _userF = _authRepo.getCachedUser();
    _fetchChauffeurs();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchChauffeurs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final headers = await _authHeaders();
      final r = await _dio.get('Chauffeur', options: Options(headers: headers));
      if (r.data is List) {
        final list = <Map<String, dynamic>>[];
        for (final e in r.data) {
          if (e is Map) list.add(Map<String, dynamic>.from(e));
        }
        setState(() {
          _chauffeurs = list;
          _applyFilter();
        });
      }
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?.toString() ?? e.message ?? "Erreur réseau");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(_chauffeurs)
          : _chauffeurs.where((d) {
        final nom = '${d['nom']} ${d['prenom']}'.toLowerCase();
        final tel = '${d['telephone'] ?? ''}'.toLowerCase();
        final cin = '${d['cin'] ?? ''}'.toLowerCase();
        final voiture = '${d['voitureMatricule'] ?? ''}'.toLowerCase();
        return nom.contains(q) || tel.contains(q) || cin.contains(q) || voiture.contains(q);
      }).toList();
    });
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m, style: const TextStyle(color: Colors.white))));
  }

  Future<void> _confirmDelete(int id, String nom) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.kBg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer chauffeur', style: TextStyle(color: AppColors.kOrange)),
        content: Text('Supprimer le chauffeur “$nom” ?',
            style: TextStyle(color: AppColors.onDark80)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler', style: TextStyle(color: AppColors.onDark60))),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Supprimer'),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final headers = await _authHeaders();
      await _dio.delete('Chauffeur/$id', options: Options(headers: headers));
      _toast("Chauffeur supprimé");
      setState(() {
        _chauffeurs.removeWhere((e) => e['id'] == id);
        _applyFilter();
      });
    } catch (e) {
      _toast("Erreur : $e");
    }
  }

  Future<void> _changerVoiture(Map<String, dynamic> chauffeur) async {
    final headers = await _authHeaders();
    try {
      // 🔹 Récupération de toutes les voitures
      final r = await _dio.get('Voitures', options: Options(headers: headers));
      final libres = <Map<String, dynamic>>[];

      // 🔹 Filtrage des voitures libres
      if (r.data is List) {
        for (final v in r.data) {
          if (v is Map) {
            final occupee = (v['occupee'] ?? '').toString().trim().toLowerCase();
            if (occupee.isEmpty || occupee == 'libre') {
              libres.add(Map<String, dynamic>.from(v));
            }
          }
        }
      }

      // 🔹 Si aucune voiture libre
      if (libres.isEmpty) {
        _toast("Aucune voiture disponible.");
        return;
      }

      // 🔹 Fenêtre de sélection
      final voiture = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          Map<String, dynamic>? selected;
          String query = '';

          return StatefulBuilder(builder: (context, setState) {
            final filtered = libres
                .where((v) {
              final s =
              '${v['matricule'] ?? ''} ${v['marque'] ?? ''} ${v['modele'] ?? ''}'.toLowerCase();
              return s.contains(query.toLowerCase());
            })
                .toList();

            return AlertDialog(
              backgroundColor: AppColors.kBg2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                "Choisir une nouvelle voiture",
                style: TextStyle(
                  color: AppColors.kOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: SizedBox(
                width: 420,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => query = v),
                      style: const TextStyle(color: AppColors.onDark),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: AppColors.kOrange),
                        hintText: "Rechercher une voiture...",
                        hintStyle: const TextStyle(color: AppColors.onDark60),
                        filled: true,
                        fillColor: AppColors.kBg3,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.onDark40),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          BorderSide(color: AppColors.kOrange, width: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                        child: Text(
                          "Aucune voiture trouvée",
                          style: TextStyle(color: AppColors.onDark60),
                        ),
                      )
                          : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final v = filtered[i];
                          final label =
                              "${v['matricule']} • ${v['marque'] ?? ''} ${v['modele'] ?? ''}"
                              " (${v['occupee'] ?? 'Libre'})";
                          final isSelected = selected == v;
                          return ListTile(
                            selected: isSelected,
                            selectedTileColor:
                            AppColors.kOrange.withOpacity(.25),
                            title: Text(
                              label,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.kOrange
                                    : AppColors.onDark80,
                              ),
                            ),
                            onTap: () => setState(() => selected = v),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annuler",
                      style: TextStyle(color: AppColors.onDark60)),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("Valider"),
                  onPressed:
                  selected == null ? null : () => Navigator.pop(context, selected),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                    selected == null ? AppColors.onDark40 : AppColors.kOrange,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            );
          });
        },
      );

      if (voiture == null) return;

      // 🔹 Corps de la requête de mise à jour
      final body = {
        "nom": chauffeur['nom'],
        "prenom": chauffeur['prenom'],
        "telephone": chauffeur['telephone'],
        "cin": chauffeur['cin'],
        "adresse": chauffeur['adresse'],
        "dateEmbauche": chauffeur['dateEmbauche'],
        "voitureId": voiture['id']
      };

      await _dio.put("Chauffeur/${chauffeur['id']}",
          data: body, options: Options(headers: headers));

      _toast("Voiture changée avec succès 🚗");
      _fetchChauffeurs();
    } catch (e) {
      _toast("Erreur : $e");
    }
  }

  void _closeDrawerIfOpen() {
    FocusScope.of(context).unfocus();
    final s = Scaffold.maybeOf(context);
    if (s?.isDrawerOpen ?? false) Navigator.of(context).pop();
  }

  void _navigate(String route) {
    _closeDrawerIfOpen();
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final routeNow = ModalRoute.of(context)?.settings.name ?? AppRoutes.chauffeursList;

    return FutureBuilder<UserModel?>(
      future: _userF,
      builder: (_, snap) {
        final user = snap.data;
        final sections =
        AppMenu.buildDefaultSections(role: user?.role, hasPaiementAlerts: () => true);

        return Scaffold(
          backgroundColor: AppColors.kBg1,
          appBar: AppBarWithMenu(
            title: 'Liste des Chauffeurs',
            onNavigate: _navigate,
            currentUser: user,
          ),
          drawer: AppSideMenu(
            activeRoute: routeNow,
            sections: sections,
            onNavigate: _navigate,
          ),
          body: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _closeDrawerIfOpen(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const BrandBackground(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _toolbar(),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Card(
                            color: AppColors.kBg2.withOpacity(.7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: AppColors.kBg3),
                            ),
                            child: _buildBody(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _toolbar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: AppColors.onDark),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: AppColors.kOrange),
              hintText: 'Rechercher (nom, CIN, téléphone, voiture...)',
              hintStyle: const TextStyle(color: AppColors.onDark60),
              filled: true,
              fillColor: AppColors.kBg3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.onDark40),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                const BorderSide(color: AppColors.kOrange, width: 1.4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ChauffeursAddPage()))
              .then((_) => _fetchChauffeurs()),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Ajouter'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.kOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        IconButton(
          tooltip: 'Rafraîchir',
          onPressed: _loading ? null : _fetchChauffeurs,
          icon: _loading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.kOrange),
          )
              : const Icon(Icons.refresh, color: AppColors.kOrange),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.kOrange));
    }
    if (_error != null) {
      return Center(
          child: Text(_error!, style: const TextStyle(color: Colors.redAccent)));
    }
    if (_filtered.isEmpty) {
      return const Center(
          child: Text('Aucun chauffeur trouvé',
              style: TextStyle(color: AppColors.onDark60)));
    }

    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, __) =>
      const Divider(color: AppColors.onDark40, height: 1),
      itemBuilder: (_, i) {
        final c = _filtered[i];
        final nom = "${c['nom'] ?? ''} ${c['prenom'] ?? ''}".trim();
        final voiture = c['voitureMatricule'] ?? '—';
        final marque = c['voitureMarque'] ?? '';
        final modele = c['voitureModele'] ?? '';
        final labelVoiture =
        voiture == '—' ? "Non assignée" : "$voiture • $marque $modele";

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.kOrange.withOpacity(.25),
            child: Text(nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                style:
                const TextStyle(color: AppColors.onDark, fontWeight: FontWeight.bold)),
          ),
          title: Text(nom,
              style: const TextStyle(
                  color: AppColors.onDark, fontWeight: FontWeight.w700)),
          subtitle: Text(
            "CIN: ${c['cin']}  •  Tél: ${c['telephone'] ?? '—'}\nVoiture: $labelVoiture",
            style: const TextStyle(color: AppColors.onDark60),
          ),
          isThreeLine: true,
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: "Changer de voiture",
                icon: const Icon(Icons.change_circle_outlined,
                    color: AppColors.kOrange),
                onPressed: () => _changerVoiture(c),
              ),
              IconButton(
                tooltip: "Supprimer",
                icon:
                const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _confirmDelete(c['id'], nom),
              ),
            ],
          ),
        );
      },
    );
  }
}
