import 'package:flutter/material.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/AppSideMenu.dart';                 // ton AppBarWithMenu (le code que tu as posté)

/// Scaffold commun à toutes les pages de l’app:
/// - AppBarWithMenu sur mobile
/// - Drawer (mobile) / Rail fixe (desktop)
/// - Sélection orange via activeRoute
class PageShell extends StatelessWidget {
  final String title;        // titre dans l’AppBar
  final String activeRoute;  // DOIT matcher AppRoutes.* de la page
  final Widget child;        // contenu de la page
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

    // Source de vérité du menu
    final sections = AppMenu.buildDefaultSections(
    );

    void go(String r) => Navigator.of(context).pushReplacementNamed(r);

    return Scaffold(
      backgroundColor: Colors.transparent,

      // AppBar (mobile uniquement)
      appBar: isWide
          ? null
          : AppBarWithMenu(
        title: title,
        sections: sections,
        activeRoute: activeRoute,
        onNavigate: (r) {
          Navigator.of(context).pop(); // fermer le drawer
          go(r);
        },
      ),

      // Drawer (mobile)
      drawer: isWide
          ? null
          : AppSideMenu(
        activeRoute: activeRoute,
        sections: sections,
        onNavigate: (r) {
          Navigator.of(context).pop();
          go(r);
        },
      ),

      // Corps responsive (rail + contenu sur desktop)
      body: SafeArea(
        child: isWide
            ? Row(
          children: [
            SizedBox(
              width: 260,
              child: Material( // assure le hit test/ink
                type: MaterialType.transparency,
                child: AppSideMenu(
                  activeRoute: activeRoute,
                  sections: sections,
                  onNavigate: go,
                ),
              ),
            ),
            const VerticalDivider(width: 0, color: Colors.transparent),
            Expanded(child: child),
          ],
        )
            : child,
      ),
    );
  }
}
