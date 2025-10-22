import 'package:flutter/material.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/background.dart';
import 'package:meubcars/Data/Models/user_model.dart';
import 'package:meubcars/Data/repositories/auth_repository.dart';
import 'package:meubcars/Data/remote/auth_remote.dart';
import 'package:meubcars/Data/Models/paiment.dart'; // pour PaiementsApi

class MainLayout extends StatefulWidget {
  final Widget child; // contenu de la page
  final String title;
  final String activeRoute;

  const MainLayout({
    super.key,
    required this.child,
    required this.title,
    required this.activeRoute,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final AuthRepository _repo = AuthRepository(AuthRemote());
  Future<UserModel?>? _userF;
  Future<int>? _badgeF;

  @override
  void initState() {
    super.initState();
    // Récupère l'utilisateur en cache + le badge au démarrage
    _userF = _repo.getCachedUser();
    _badgeF = _fetchBadge();
  }

  /// 🔹 Récupère le badge (paiements dus ou en retard)
  Future<int> _fetchBadge() async {
    try {
      final api = await PaiementsApi.authed();
      final summary = await api.fetchSummary();
      return summary.badgeCount;
    } catch (e, s) {
      debugPrint('⚠️ Erreur lors du fetch du badge: $e');
      debugPrint('$s');
      return 0;
    }
  }

  /// 🔹 Navigation + refresh du badge après retour
  void _go(String route) async {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) Navigator.of(context).pop();
    if (widget.activeRoute == route) return;

    await Navigator.of(context).pushNamed(route);

    // Rafraîchit le badge après retour
    if (mounted) {
      setState(() => _badgeF = _fetchBadge());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _userF,
      builder: (context, snapUser) {
        final user = snapUser.data;

        return FutureBuilder<int>(
          future: _badgeF,
          builder: (context, snapBadge) {
            final badge = snapBadge.data ?? 0;

            final sections = AppMenu.buildDefaultSections(
              role: user?.role,
              hasPaiementAlerts: () => badge > 0,
            );

            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBarWithMenu(
                title: widget.title,
                onNavigate: _go,
                currentUser: user,
              ),
              drawer: AppSideMenu(
                key: const ValueKey('AppSideMenu'),
                activeRoute: widget.activeRoute,
                sections: sections,
                onNavigate: _go,
              ),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  const BrandBackground(),
                  SafeArea(child: widget.child),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
//www