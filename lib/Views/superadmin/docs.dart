import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:meubcars/utils/tabs/AssuranceTab.dart';
import 'package:meubcars/utils/tabs/CarteGriseTab.dart';
import 'package:meubcars/utils/tabs/VignetteTab.dart';
import 'package:meubcars/utils/tabs/VisiteTab.dart';
import 'package:meubcars/utils/tabs/TaxeTab.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/background.dart';
import 'package:meubcars/Data/Models/user_model.dart';
import 'package:meubcars/Data/repositories/auth_repository.dart';
import 'package:meubcars/Data/remote/auth_remote.dart';

class DocumentationVoiturePage extends StatefulWidget {
  final int voitureId;
  final String voitureNom;

  const DocumentationVoiturePage({
    super.key,
    required this.voitureId,
    required this.voitureNom,
  });

  @override
  State<DocumentationVoiturePage> createState() =>
      _DocumentationVoiturePageState();
}

class _DocumentationVoiturePageState extends State<DocumentationVoiturePage> {
  final AuthRepository _repo = AuthRepository(AuthRemote());
  Future<UserModel?>? _userF;

  int _selectedIndex = 0;

  final List<String> _sections = [
    "Assurances",
    "Cartes grises",
    "Vignettes",
    "Visites",
    "Taxes",
  ];

  @override
  void initState() {
    super.initState();
    _userF = _repo.getCachedUser();
  }

  @override
  Widget build(BuildContext context) {
    final routeNow =
        ModalRoute.of(context)?.settings.name ?? '/voitures/documents';

    return FutureBuilder<UserModel?>(
      future: _userF,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
                child: CircularProgressIndicator(color: Colors.white70)),
          );
        }

        if (!snap.hasData || snap.data == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 42),
                  const SizedBox(height: 12),
                  const Text("Impossible de charger l'utilisateur",
                      style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () =>
                        setState(() => _userF = _repo.getCachedUser()),
                    icon: const Icon(Icons.refresh),
                    label: const Text("Réessayer"),
                  ),
                ],
              ),
            ),
          );
        }

        final user = snap.data!;
        final sections = AppMenu.buildDefaultSections(role: user.role);

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBarWithMenu(
            title: 'Documentation — ${widget.voitureNom}',
            onNavigate: _go,
            sections: sections,
            activeRoute: routeNow,
            currentUser: user,
          ),
          drawer: AppSideMenu(
            activeRoute: routeNow,
            sections: sections,
            onNavigate: _go,
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              const BrandBackground(),
              SafeArea(
                child: Column(
                  children: [
                    // ===== MENU HORIZONTAL =====
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_sections.length, (i) {
                            final selected = i == _selectedIndex;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.orange.withOpacity(0.18)
                                      : const Color(0xFF1E1E21),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected
                                        ? Colors.orange
                                        : Colors.white24,
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () =>
                                      setState(() => _selectedIndex = i),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 10),
                                    child: Text(
                                      _sections[i],
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.orange
                                            : Colors.white70,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ===== CONTENU =====
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildSection(_selectedIndex),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _go(String route) async {
    final s = Scaffold.maybeOf(context);
    if (s?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 250));
    }

    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;

    if (mounted) {
      Navigator.of(context).pushReplacementNamed(route);
    }
  }

  Widget _buildSection(int index) {
    switch (index) {
      case 0:
        return AssuranceTab(voitureId: widget.voitureId);
      case 1:
        return CarteGriseTab(voitureId: widget.voitureId);
      case 2:
        return VignetteTab(voitureId: widget.voitureId);
      case 3:
        return VisiteTab(voitureId: widget.voitureId);
      case 4:
        return TaxeTab(voitureId: widget.voitureId);
      default:
        return const Center(
          child: Text("Section à venir...",
              style: TextStyle(color: Colors.white70)),
        );
    }
  }
}
