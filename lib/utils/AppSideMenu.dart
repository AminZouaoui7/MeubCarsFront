import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:meubcars/Data/Models/paiment.dart';
import 'package:meubcars/core/cache/CacheHelper.dart';
import 'dart:html' as html;

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

/// ===================== Colors (MeubCars) =====================
class AppColors {
  static const Color primaryA = Color(0xFFD97B06);
  static const Color primaryB = Color(0xFFF4A30C);
  static const Color kOrange = Color(0xFFE4631D);
  static const Color kOrangeLight = Color(0x20E4631D);
  static const Color kBg1 = Color(0xFF0C0C0D);
  static const Color kBg2 = Color(0xFF151517);
  static const Color kBg3 = Color(0xFF1E1E21);
  static const Color onDark = Colors.white;
  static const Color onDark80 = Color(0xCCFFFFFF);
  static const Color onDark60 = Color(0x99FFFFFF);
  static const Color onDark40 = Color(0x66FFFFFF);
}

/// ===================== Routes catalog =====================
class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const profile = '/profile';
  static const settings = '/settings';
  static const voituresList = '/voitures';
  static const voituresAdd = '/voitures/add';
  static const voituresEdit = '/voitures/edit';
  static const paiementsHistory = '/paiements/history';
  static const chauffeursList = '/chauffeurs';
  static const chauffeursAdd = '/chauffeurs/add';
  static const societesList = '/societes';
  static const societesAdd = '/societes/add';
  static const missionsCreate = '/missions/create';
  static const superAdminAddAdmin = '/superadmin/addadmin';
  static const superDocordremision = '/superadmin/docordremision';
  static const voituresFrais = '/voitures/frais';
  static const voitureDetails = '/voitures/details';
  static const postLogin = '/postLogin';

}
/// ===================== Menu models =====================
class MenuItem {
  final String title;
  final IconData icon;
  final String route;
  const MenuItem({required this.title, required this.icon, required this.route});
}

class MenuSection {
  final String title;
  final IconData icon;
  final List<MenuItem> items;
  final bool Function()? hasAlerts;
  const MenuSection({
    required this.title,
    required this.icon,
    this.items = const [],
    this.hasAlerts,
  });
}

class AppMenu {
  /// 🧩 Build menu dynamically based on user role
  static List<MenuSection> buildDefaultSections({
    String? role, // "SuperAdmin", "Admin", "Employe"
    bool Function()? hasPaiementAlerts,
  }) {
    // 🔐 1) Secure role detection
    try {
      if ((role == null || role.isEmpty) && CacheHelper.isReady) {
        final cachedRole = CacheHelper.getData<String>(key: 'role');
        if (cachedRole != null && cachedRole.trim().isNotEmpty) {
          role = cachedRole.trim();
        }
      }
    } catch (e) {
      debugPrint('⚠️ AppMenu.buildDefaultSections: cannot read role yet ($e)');
      role ??= 'Employe';
    }

    // 🔄 2) Fallback role if still null
    role ??= 'Employe';

    // 🧱 3) Build menu safely
    final sections = <MenuSection>[
      MenuSection(
        title: 'Voitures',
        icon: Icons.directions_car_filled_outlined,
        items: const [
          MenuItem(
            title: 'Liste des voitures',
            icon: Icons.format_list_bulleted,
            route: AppRoutes.voituresList,
          ),
          MenuItem(
            title: 'Ajouter voiture',
            icon: Icons.add_box_outlined,
            route: AppRoutes.voituresAdd,
          ),
        ],
      ),
      MenuSection(
        title: 'Chauffeurs',
        icon: Icons.badge_outlined,
        items: const [
          MenuItem(
            title: 'Liste des chauffeurs',
            icon: Icons.people_alt_outlined,
            route: AppRoutes.chauffeursList,
          ),
          MenuItem(
            title: 'Ajouter chauffeur',
            icon: Icons.person_add_alt_1,
            route: AppRoutes.chauffeursAdd,
          ),
        ],
      ),
      MenuSection(
        title: 'Paiements',
        icon: Icons.payments_outlined,
        hasAlerts: hasPaiementAlerts,
        items: const [
          MenuItem(
            title: 'Historique des paiements',
            icon: Icons.history,
            route: AppRoutes.paiementsHistory,
          ),
        ],
      ),
      MenuSection(
        title: 'Missions',
        icon: Icons.assignment_outlined,
        items: const [
          MenuItem(
            title: 'Nouvel ordre',
            icon: Icons.add_task,
            route: AppRoutes.missionsCreate,
          ),
        ],
      ),
    ];

    // 👑 4) Add SuperAdmin section only when required
    if (role == 'SuperAdmin') {
      sections.add(
        MenuSection(
          title: 'Super Admin',
          icon: Icons.security_outlined,
          items: const [
            MenuItem(
              title: 'Ajouter admin',
              icon: Icons.admin_panel_settings_outlined,
              route: AppRoutes.superAdminAddAdmin,
            ),
            MenuItem(
              title: 'Ordres de mission',
              icon: Icons.directions_car_filled_outlined,
              route: AppRoutes.superDocordremision,
            ),
          ],
        ),
      );
    }

    return sections;
  }
}
/// ===================== AppSideMenu =====================
class AppSideMenu extends StatefulWidget {
  final String activeRoute;
  final void Function(String route) onNavigate;
  final List<MenuSection> sections;
  final double desktopBreakpoint;
  final double railWidth;

  const AppSideMenu({
    super.key,
    required this.activeRoute,
    required this.onNavigate,
    required this.sections,
    this.desktopBreakpoint = 980,
    this.railWidth = 280,
  });

  @override
  State<AppSideMenu> createState() => _AppSideMenuState();
}

class _AppSideMenuState extends State<AppSideMenu> {
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _expandedIndex = null;
  }

  @override
  void didUpdateWidget(covariant AppSideMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeChanged = oldWidget.activeRoute != widget.activeRoute;
    final sectionsChanged = !identical(oldWidget.sections, widget.sections);
    if (routeChanged || sectionsChanged) {
      final sectionIndex = _sectionIndexForRoute(widget.activeRoute);
      setState(() {
        _expandedIndex = sectionIndex;
      });
    }
  }

  int? _sectionIndexForRoute(String? route) {
    if (route == null) return null;
    for (int i = 0; i < widget.sections.length; i++) {
      final s = widget.sections[i];
      if (s.items.length <= 1) continue;
      if (s.items.any((it) => it.route == route)) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= widget.desktopBreakpoint;
    return isWide
        ? _DesktopRail(
      width: widget.railWidth,
      sections: widget.sections,
      activeRoute: widget.activeRoute,
      expandedIndex: _expandedIndex,
      onToggle: (i) =>
          setState(() => _expandedIndex = _expandedIndex == i ? null : i),
      onNavigate: widget.onNavigate,
    )
        : _MobileDrawer(
      sections: widget.sections,
      activeRoute: widget.activeRoute,
      expandedIndex: _expandedIndex,
      onToggle: (i) =>
          setState(() => _expandedIndex = _expandedIndex == i ? null : i),
      onNavigate: widget.onNavigate,
    );
  }
}
/// ===================== Desktop rail =====================
class _DesktopRail extends StatelessWidget {
  final double width;
  final List<MenuSection> sections;
  final String activeRoute;
  final int? expandedIndex;
  final void Function(int) onToggle;
  final void Function(String) onNavigate;

  const _DesktopRail({
    required this.width,
    required this.sections,
    required this.activeRoute,
    required this.expandedIndex,
    required this.onToggle,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.kBg1,
        border: Border(
          right: BorderSide(color: Colors.black.withOpacity(0.2), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const _BrandHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: sections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final s = sections[index];
                  final isActiveSection =
                  s.items.any((it) => it.route == activeRoute);
                  final expanded = expandedIndex == index;
                  final hasAlerts = s.hasAlerts?.call() ?? false;

                  return _RailSection(
                    section: s,
                    expanded: expanded,
                    hasAlerts: hasAlerts,
                    isActiveSection: isActiveSection,
                    onToggle: () => onToggle(index),
                    onNavigate: onNavigate,
                    activeRoute: activeRoute,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Déconnexion', style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    // 1️⃣ Clear all cached auth data
                    await CacheHelper.clearData();
                    await Future.delayed(const Duration(milliseconds: 150));

                    // 2️⃣ Extra cleanup for Flutter Web (localStorage + reload)
                    if (kIsWeb) {

                      try {
                        html.window.localStorage.clear();
                        html.window.sessionStorage.clear();
                        print('🧹 LocalStorage cleared successfully');
                      } catch (e) {
                        print('Error clearing localStorage: $e');
                      }

                      // 3️⃣ Force reload to guarantee clean state
                      html.window.location.replace('/#/login');
                      return; // stop further navigation
                    }

                    // 4️⃣ Mobile / desktop fallback
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
                    }
                  },
              ),
            ),

          ],
        ),
      ),
    );
  }
}

/// ===================== Section dans Desktop rail =====================


class _RailSection extends StatefulWidget {
  final MenuSection section;
  final bool expanded;
  final bool hasAlerts;
  final bool isActiveSection;
  final VoidCallback onToggle;
  final void Function(String) onNavigate;
  final String activeRoute;

  const _RailSection({
    required this.section,
    required this.expanded,
    required this.hasAlerts,
    required this.isActiveSection,
    required this.onToggle,
    required this.onNavigate,
    required this.activeRoute,
  });

  @override
  State<_RailSection> createState() => _RailSectionState();
}

class _RailSectionState extends State<_RailSection>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _heightFactor;

  @override
  void initState() {
    super.initState();

    try {
      _controller = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );

      _heightFactor = CurvedAnimation(
        parent: _controller!,
        curve: Curves.fastOutSlowIn,
      );

      // Synchronise the state
      if (widget.expanded) {
        _controller!.value = 1.0;
      }
    } catch (e) {
      debugPrint("⚠️ Animation init error in _RailSectionState: $e");
      _controller = null;
      _heightFactor = const AlwaysStoppedAnimation(1.0);
    }
  }

  @override
  void didUpdateWidget(covariant _RailSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      if (widget.expanded) {
        _controller?.forward();
      } else {
        _controller?.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleColor =
    widget.isActiveSection ? AppColors.kOrange : AppColors.onDark;
    final iconColor =
    widget.isActiveSection ? AppColors.kOrange : AppColors.onDark;
    final itemCount = widget.section.items.length;

    final heightAnim =
        _heightFactor ?? const AlwaysStoppedAnimation<double>(1.0);
    final rotationAnim =
        _controller ?? AnimationController(vsync: this, duration: Duration.zero);

    return Container(
      decoration: BoxDecoration(
        color: widget.expanded ? AppColors.kBg3 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (itemCount == 1) {
                  widget.onNavigate(widget.section.items.first.route);
                } else if (itemCount > 1) {
                  widget.onToggle();
                }
              },
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Icon(widget.section.icon, color: iconColor, size: 22),
                        if (widget.hasAlerts)
                          Positioned(
                            right: -1,
                            top: -1,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.section.title,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (itemCount > 1)
                      RotationTransition(
                        turns:
                        Tween(begin: 0.0, end: 0.5).animate(rotationAnim),
                        child: Icon(Icons.arrow_drop_down,
                            color: AppColors.onDark60, size: 24),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: heightAnim,
            axisAlignment: 1.0,
            child: Column(
              children: widget.section.items.map((item) {
                return _SubMenuItem(
                  item: item,
                  activeRoute: widget.activeRoute,
                  onNavigate: widget.onNavigate,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
/// ===================== Sous-menu (éléments enfants) =====================
class _SubMenuItem extends StatelessWidget {
  final MenuItem item;
  final String activeRoute;
  final void Function(String) onNavigate;

  const _SubMenuItem({
    required this.item,
    required this.activeRoute,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final selected = item.route == activeRoute;
    final textColor = selected ? AppColors.kOrange : AppColors.onDark80;
    final iconColor = selected ? AppColors.kOrange : AppColors.onDark60;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onNavigate(item.route),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.only(left: 40, right: 8, bottom: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.kOrangeLight : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(
                color: AppColors.kOrange.withOpacity(0.3), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 18, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.kOrange,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===================== En-tête du menu =====================
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.onDark40, width: 1.5),
            ),
              child: Image.asset(
                'assets/images/fa255587-6402-42e0-a7df-b72b9f6f9e69.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.directions_car, color: Colors.white, size: 28),
              ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'MeubCars',
              style: TextStyle(
                color: AppColors.onDark,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
/// ===================== Mobile drawer =====================
class _MobileDrawer extends StatelessWidget {
  final List<MenuSection> sections;
  final String activeRoute;
  final int? expandedIndex;
  final void Function(int) onToggle;
  final void Function(String) onNavigate;

  const _MobileDrawer({
    required this.sections,
    required this.activeRoute,
    required this.expandedIndex,
    required this.onToggle,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      child: Container(
        decoration: const BoxDecoration(color: AppColors.kBg1),
        child: SafeArea(
          child: Column(
            children: [
              const _BrandHeader(),
              const Divider(color: AppColors.kBg3, height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: sections.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final s = sections[index];
                    final isActiveSection =
                    s.items.any((it) => it.route == activeRoute);
                    final expanded = expandedIndex == index;
                    final hasAlerts = s.hasAlerts?.call() ?? false;

                    return _MobileSection(
                      section: s,
                      expanded: expanded,
                      hasAlerts: hasAlerts,
                      isActiveSection: isActiveSection,
                      onToggle: () => onToggle(index),
                      onNavigate: (route) {
                        Navigator.of(context).pop();
                        onNavigate(route);
                      },
                      activeRoute: activeRoute,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('Déconnexion', style: TextStyle(color: Colors.redAccent)),
                    onTap: () async {
                      // 1️⃣ Clear all cached auth data
                      await CacheHelper.clearData();

                      // 2️⃣ Force a short delay to ensure storage flush (important on Flutter Web)
                      await Future.delayed(const Duration(milliseconds: 120));

                      // 3️⃣ Redirect cleanly to login and clear navigation stack
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
                      }
                    },
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
class _MobileSection extends StatefulWidget {
  final MenuSection section;
  final bool expanded;
  final bool hasAlerts;
  final bool isActiveSection;
  final VoidCallback onToggle;
  final void Function(String) onNavigate;
  final String activeRoute;

  const _MobileSection({
    required this.section,
    required this.expanded,
    required this.hasAlerts,
    required this.isActiveSection,
    required this.onToggle,
    required this.onNavigate,
    required this.activeRoute,
  });

  @override
  State<_MobileSection> createState() => _MobileSectionState();
}

class _MobileSectionState extends State<_MobileSection>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _heightFactor;

  @override
  void initState() {
    super.initState();

    try {
      _controller = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );

      _heightFactor = CurvedAnimation(
        parent: _controller!,
        curve: Curves.fastOutSlowIn,
      );

      if (widget.expanded) {
        _controller!.value = 1.0;
      }
    } catch (e) {
      debugPrint('⚠️ _MobileSection animation init error: $e');
      _controller = null;
      _heightFactor = const AlwaysStoppedAnimation(1.0);
    }
  }

  @override
  void didUpdateWidget(covariant _MobileSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null) return; // ✅ safety
    if (widget.expanded != oldWidget.expanded) {
      if (widget.expanded) {
        _controller!.forward();
      } else {
        _controller!.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleColor =
    widget.isActiveSection ? AppColors.kOrange : AppColors.onDark;
    final iconColor =
    widget.isActiveSection ? AppColors.kOrange : AppColors.onDark;
    final itemCount = widget.section.items.length;

    final controller = _controller;
    final heightFactor = _heightFactor ?? const AlwaysStoppedAnimation(1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: widget.expanded ? AppColors.kBg3 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (itemCount == 1) {
                  widget.onNavigate(widget.section.items.first.route);
                } else if (itemCount > 1) {
                  widget.onToggle();
                }
              },
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Icon(widget.section.icon, color: iconColor, size: 24),
                        if (widget.hasAlerts)
                          Positioned(
                            right: -1,
                            top: -1,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.section.title,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (itemCount > 1 && controller != null)
                      RotationTransition(
                        turns:
                        Tween(begin: 0.0, end: 0.5).animate(controller),
                        child: Icon(Icons.arrow_drop_down,
                            color: AppColors.onDark60, size: 28),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: heightFactor,
            axisAlignment: 1.0,
            child: Column(
              children: widget.section.items.map((item) {
                return _MobileSubMenuItem(
                  item: item,
                  activeRoute: widget.activeRoute,
                  onNavigate: widget.onNavigate,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileSubMenuItem extends StatelessWidget {
  final MenuItem item;
  final String activeRoute;
  final void Function(String) onNavigate;

  const _MobileSubMenuItem({
    required this.item,
    required this.activeRoute,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final selected = item.route == activeRoute;
    final textColor = selected ? AppColors.kOrange : AppColors.onDark80;
    final iconColor = selected ? AppColors.kOrange : AppColors.onDark60;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onNavigate(item.route),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          margin: const EdgeInsets.only(left: 40, right: 8, bottom: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.kOrangeLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(
                color: AppColors.kOrange.withOpacity(0.3), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 20, color: iconColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.kOrange,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
