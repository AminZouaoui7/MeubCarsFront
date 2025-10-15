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
  late final AuthRepository _repo = AuthRepository(AuthRemote());
  late Future<UserModel?> _userF;
  late Future<int> _badgeF;

  @override
  void initState() {
    super.initState();
    _userF = _repo.getCachedUser();
    _badgeF = _fetchBadge();
  }

  Future<int> _fetchBadge() async {
    try {
      final api = await PaiementsApi.authed();
      final summary = await api.fetchSummary();
      return summary.badgeCount;
    } catch (e) {
      debugPrint('Erreur badge: $e');
      return 0;
    }
  }

  void _go(String route) async {
    final s = Scaffold.maybeOf(context);
    if (s?.isDrawerOpen ?? false) Navigator.of(context).pop();
    if (widget.activeRoute == route) return;

    await Navigator.of(context).pushNamed(route);

    // 🔁 refresh badge au retour
    setState(() => _badgeF = _fetchBadge());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _userF,
      builder: (_, snapUser) {
        final user = snapUser.data;

        return FutureBuilder<int>(
          future: _badgeF,
          builder: (_, snapBadge) {
            final badge = snapBadge.data ?? 0;

            final sections = AppMenu.buildDefaultSections(
              role: user?.role,
              nbPaiementsEnRetard: badge,
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
