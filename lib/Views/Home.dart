import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:meubcars/Data/Dtos/DashboardApi.dart';
import 'package:meubcars/Data/Models/paiment.dart';
import 'package:meubcars/Data/Models/user_model.dart';
import 'package:meubcars/Data/repositories/auth_repository.dart';
import 'package:meubcars/Data/remote/auth_remote.dart';
import 'package:meubcars/core/cache/CacheHelper.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/DonutChartCard.dart';
import 'package:meubcars/utils/PaiementsDuMoisCard.dart' as pdm;
import 'package:meubcars/utils/background.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/core/api/endpoints.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final AuthRepository _repo = AuthRepository(AuthRemote());
  Future<UserModel?>? _userF;
  Future<int>? _nbPaiementsF;
  Future<bool>? _authCheck;


  @override
  void initState() {
    super.initState();

    if (!CacheHelper.isReady) {
      debugPrint('🕒 CacheHelper not ready inside Home → initializing...');
      CacheHelper.init();
    }

    _authCheck = _verifyAuth();
    _userF = _loadUser();
    _nbPaiementsF = _fetchNbPaiementsEnRetard();
  }


  // ================= AUTH CHECK =================
  Future<bool> _verifyAuth() async {
    String? token;
    try {
      token = CacheHelper.getData<String>(key: 'token');
    } catch (e) {
      debugPrint('⚠️ Token read failed: $e');
    }

    final t = (token ?? '').trim();
    if (t.isEmpty || JwtDecoder.isExpired(t)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.login, (r) => false);
        }
      });
      return false;
    }
    return true;
  }

  Future<UserModel?> _loadUser() async {
    try {
      final raw = CacheHelper.getData<String>(key: 'user');
      if (raw != null && raw.trim().isNotEmpty) {
        return UserModel.fromJson(jsonDecode(raw));
      }
    } catch (e) {
      debugPrint('⚠️ User cache read failed: $e');
    }
    return null;
  }

  // ================= LOAD USER =================

  Future<int> _fetchNbPaiementsEnRetard() async {
    try {
      final api = await PaiementsApi.authed();
      final summary = await api.fetchSummary();
      return summary.badgeCount;
    } catch (e) {
      debugPrint('Erreur chargement paiements: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authCheck ?? Future.value(false),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.data == false) return const SizedBox.shrink();

        return FutureBuilder<UserModel?>(
          future: _userF,
          builder: (_, snapUser) {
            if (snapUser.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final user = snapUser.data;

            if (user == null) {
              return const Scaffold(
                body: Center(
                  child: Text('Utilisateur introuvable', style: TextStyle(color: Colors.redAccent)),
                ),
              );
            }

            return FutureBuilder<int>(
              future: _nbPaiementsF,
              builder: (_, snapBadge) {
                final nbBadge = snapBadge.data ?? 0;

                final sections = AppMenu.buildDefaultSections(
                  role: user.role ?? 'Employe', // ✅ fallback role
                  hasPaiementAlerts: () => nbBadge > 0,
                );

                final routeNow =
                    ModalRoute.of(context)?.settings.name ?? AppRoutes.home;
                void closeDrawerIfOpen() {
                  final s = Scaffold.maybeOf(context);
                  if (s?.isDrawerOpen ?? false) Navigator.of(context).pop();
                }

                void go(String r) async {
                  closeDrawerIfOpen();
                  if (routeNow == r) return;
                  await Navigator.of(context).pushNamed(r);
                  if (mounted) {
                    setState(() => _nbPaiementsF = _fetchNbPaiementsEnRetard());
                  }
                }

                return Scaffold(
                  key: const ValueKey('HomeScaffold'),
                  backgroundColor: Colors.transparent,
                  appBar: AppBarWithMenu(
                    title: 'Home',
                    onNavigate: go,
                    currentUser: user,
                  ),
                  drawer: AppSideMenu(
                    key: const ValueKey('AppSideMenu'),
                    activeRoute: routeNow,
                    sections: sections,
                    onNavigate: go,
                  ),
                  body: const Stack(
                    fit: StackFit.expand,
                    children: [
                      BrandBackground(),
                      _HomeContent(),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}


// ⬇️ le reste ( _HomeContent / InfoStatCard ) ne change pas

class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  DashboardApi? _api;
  Future<Map<String, int>>? _voituresF;
  Future<int>? _missionsF;
  Future<int>? _saisieCountF;

  @override
  void initState() {
    super.initState();

    _api = DashboardApi();
    _voituresF = _api?.getVoituresStats();
    _missionsF = _api?.getTotalMissions();
    _saisieCountF = _api?.getSaisieCount(); // ✅ récupère le nombre de voitures saisies
  }

  void _openPaymentDetail(BuildContext context, PaymentItem it) {
    switch (it.type) {
      case PaymentType.Assurance:
        Navigator.pushNamed(context, '/assurances', arguments: {'voitureId': it.voitureId});
        break;
      case PaymentType.CarteGrise:
        Navigator.pushNamed(context, '/cartesGrises', arguments: {'voitureId': it.voitureId});
        break;
      case PaymentType.Vignette:
        Navigator.pushNamed(context, '/vignettes', arguments: {'voitureId': it.voitureId});
        break;
      case PaymentType.VisiteTechnique:
        Navigator.pushNamed(context, '/visitesTechniques', arguments: {'voitureId': it.voitureId});
        break;
      case PaymentType.Entretien:
        Navigator.pushNamed(context, '/voitures/frais', arguments: {'voitureId': it.voitureId});
        break;
      case PaymentType.Autre:
        Navigator.pushNamed(context, '/paiements', arguments: {
          'voitureId': it.voitureId,
          'type': it.type,
        });
        break;
      case PaymentType.Taxe:
        throw UnimplementedError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w >= 1100;
    void _openHistory() => Navigator.pushNamed(context, AppRoutes.paiementsHistory);

    final cardBg = const Color(0xFF17181B).withOpacity(.85);
    final border = BorderSide(color: Colors.white.withOpacity(.06));

    Widget leftColumn() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dashboard',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 16),

        // ✅ FutureBuilder combiné pour voitures, missions et saisies
        FutureBuilder<List<dynamic>>(
          future: Future.wait([
            _voituresF ?? Future.value(<String, int>{}),
            _missionsF ?? Future.value(0),
            _saisieCountF ?? Future.value(0),
          ]),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Erreur chargement stats: ${snap.error}',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              );
            }

            final voitures = snap.data![0] as Map<String, int>;
            final missions = snap.data![1] as int;
            final saisies = snap.data![2] as int;

            return LayoutBuilder(
              builder: (context, c) {
                final max = c.maxWidth;
                const gap = 24.0;
                final tileW = (max - gap * 3) / 4; // 4 cartes côte à côte

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      InfoStatCard(
                        width: tileW,
                        title: 'Voitures en panne',
                        subtitleLeft: '${voitures['enPanne'] ?? 0}',
                        icon: Icons.car_repair_rounded,
                        progress: 0,
                        bg: cardBg,
                        border: border,
                      ),
                      const SizedBox(width: gap),
                      InfoStatCard(
                        width: tileW,
                        title: 'Voitures en parking',
                        subtitleLeft: '${voitures['enParking'] ?? 0}',
                        icon: Icons.local_parking_rounded,
                        progress: 0,
                        bg: cardBg,
                        border: border,
                      ),
                      const SizedBox(width: gap),
                      InfoStatCard(
                        width: tileW,
                        title: 'Ordres de mission',
                        subtitleLeft: '$missions',
                        icon: Icons.assignment_rounded,
                        progress: 0,
                        bg: cardBg,
                        border: border,
                      ),
                      const SizedBox(width: gap),
                      InfoStatCard(
                        width: tileW,
                        title: 'Voitures saisies',
                        subtitleLeft: '$saisies',
                        icon: Icons.gavel_rounded,
                        progress: 0,
                        bg: cardBg,
                        border: border,
                        accent: Colors.orangeAccent,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),

        const SizedBox(height: 20),

        // ✅ Paiements du mois
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.fromBorderSide(border),
          ),
          padding: const EdgeInsets.all(12),
          child: pdm.PaiementsDuMoisCard(
            initialMonth: DateTime.now(),
            dueDays: 7,
            onView: (it) => _openPaymentDetail(context, it as PaymentItem),
            onOpenHistory: _openHistory,
          ),
        ),
      ],
    );

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF121214).withOpacity(.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(.05)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: isDesktop
                      ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: leftColumn()),
                      const SizedBox(width: 16),
                    ],
                  )
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      leftColumn(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InfoStatCard extends StatelessWidget {
  final double width;
  final String title;
  final String subtitleLeft;
  final IconData icon;
  final double progress;
  final Color bg;
  final BorderSide border;
  final Color? accent;
  final double height;

  const InfoStatCard({
    super.key,
    required this.width,
    required this.title,
    required this.subtitleLeft,
    required this.icon,
    required this.progress,
    required this.bg,
    required this.border,
    this.accent,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    final a = accent ?? const Color(0xFFFF8A3D);
    final a2 = Color.lerp(a, Colors.white, .25)!;
    const cardRadius = 20.0;

    double bigNumberSizeForWidth(double w) {
      if (w >= 360) return 40;
      if (w >= 300) return 34;
      if (w >= 240) return 30;
      return 26;
    }

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cardRadius),
          boxShadow: [
            BoxShadow(color: a.withOpacity(.12), blurRadius: 28, offset: const Offset(0, 10)),
            BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 8, offset: const Offset(0, 4)),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [a.withOpacity(.15), Colors.white.withOpacity(.02), Colors.white.withOpacity(.01)],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.fromBorderSide(border),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bg.withOpacity(.96), bg.withOpacity(.88)],
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, c) {
              final big = bigNumberSizeForWidth(c.maxWidth);

              return Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [a.withOpacity(.20), a.withOpacity(.08)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: a.withOpacity(.22), width: 1.2),
                          boxShadow: [
                            BoxShadow(color: a.withOpacity(.14), blurRadius: 6, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Icon(icon, color: a2, size: 20),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.88),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: .8,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitleLeft,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.98),
                      fontWeight: FontWeight.w900,
                      fontSize: big,
                      letterSpacing: .2,
                      height: .95,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(.18),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
