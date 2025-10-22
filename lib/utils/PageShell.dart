import 'package:flutter/material.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/core/cache/CacheHelper.dart';

/// 🧱 Scaffold commun à toutes les pages de l’app:
/// - AppBarWithMenu sur mobile
/// - Drawer (mobile) / Rail fixe (desktop)
/// - Sélection orange via activeRoute
class PageShell extends StatelessWidget {
  final String title; // Titre dans l’AppBar
  final String activeRoute; // DOIT matcher AppRoutes.* de la page
  final Widget child; // Contenu de la page
  final double desktopBreakpoint;

  const PageShell({
    super.key,
    required this.title,
    required this.activeRoute,
    required this.child,
    this.desktopBreakpoint = 980,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= desktopBreakpoint;

    // 🔹 Récupère le rôle utilisateur stocké localement (sécurisé)
    final role = CacheHelper.getData<String>(key: 'role') ?? 'Employe';

    // 🔹 Construit les sections selon le rôle
    final sections = AppMenu.buildDefaultSections(role: role);

    // 🔹 Navigation avec remplacement (préserve cohérence du shell)
    void go(String route) {
      if (ModalRoute.of(context)?.settings.name == route) return;
      Navigator.of(context).pushReplacementNamed(route);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,

      // 🔸 AppBar (mobile uniquement)
      appBar: isWide
          ? null
          : AppBarWithMenu(
        title: title,
        sections: sections,
        activeRoute: activeRoute,
        onNavigate: (r) {
          Navigator.of(context).maybePop(); // ferme le Drawer s’il est ouvert
          go(r);
        },
      ),

      // 🔸 Drawer (mobile)
      drawer: isWide
          ? null
          : AppSideMenu(
        activeRoute: activeRoute,
        sections: sections,
        onNavigate: (r) {
          Navigator.of(context).maybePop();
          go(r);
        },
      ),

      // 🔸 Corps responsive (Rail fixe sur desktop)
      body: SafeArea(
        child: isWide
            ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 260,
              child: Material(
                type: MaterialType.transparency,
                child: AppSideMenu(
                  activeRoute: activeRoute,
                  sections: sections,
                  onNavigate: go,
                ),
              ),
            ),
            const VerticalDivider(
                width: 0, color: Colors.transparent), // Espacement visuel
            Expanded(child: child),
          ],
        )
            : child,
      ),
    );
  }
}
