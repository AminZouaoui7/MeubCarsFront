import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:meubcars/core/cache/cacheHelper.dart';
import 'package:meubcars/core/api/dio_consumer.dart';
import 'package:meubcars/Data/remote/auth_remote.dart';
import 'package:meubcars/Data/repositories/auth_repository.dart';
import 'package:meubcars/Views/OrdreMission/OrdreMissionFormPage.dart';
import 'package:meubcars/Views/ProfilePage.dart';
import 'package:meubcars/Views/SettingsPage.dart';

import 'package:meubcars/Views/Voiture/Ajoutervoiture.dart';
import 'package:meubcars/Views/Voiture/CarDetailsPage.dart';
import 'package:meubcars/Views/Voiture/Cr%C3%A9erflux.dart';
import 'package:meubcars/Views/Voiture/FluxDetailPage.dart';
import 'package:meubcars/Views/Voiture/FraisVoiturePage.dart';
import 'package:meubcars/Views/Voiture/Listevoitures.dart';
import 'package:meubcars/Views/Voiture/Fluxdetransport.dart';
import 'package:meubcars/Views/Voiture/VoitureEditPage.dart';

import 'package:meubcars/Views/chaffeurs/Listechauffeurs.dart';
import 'package:meubcars/Views/chaffeurs/Ajouterchauffeur.dart';
import 'package:meubcars/Views/Sociétés/Ajoutersociété.dart';
import 'package:meubcars/Views/Sociétés/Listesociétés.dart';
import 'package:meubcars/Views/paiment/PaiementsHistoryPage.dart';
import 'package:meubcars/Views/paiment/Paiementsmois.dart';
import 'package:meubcars/Views/superadmin/addAdmin.dart';
import 'package:meubcars/Views/superadmin/docOrdreMision.dart';
import 'package:meubcars/Views/superadmin/docs.dart';

import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/PageShell.dart';
import 'package:meubcars/utils/AppBar.dart';

import 'package:meubcars/Views/Home.dart';
import 'package:meubcars/PostLoginTransition.dart'; // SplashScreen

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheHelper.init();

  // === Locale FR pour DateFormat (évite LocaleDataException) ===
  await initializeDateFormatting('fr_FR', null);
  Intl.defaultLocale = 'fr_FR';

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const MeubCarsApp());
}

class MeubCarsApp extends StatelessWidget {
  const MeubCarsApp({super.key});

  Widget _wrap(String title, String activeRoute, Widget child) {
    return PageShell(title: title, activeRoute: activeRoute, child: child);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeubCars',
      debugShowCheckedModeBanner: false,

      // === Localisations ===
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates:  [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE4631D),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0C0C0D),
      ),

      initialRoute: '/',
      routes: {
        // Splash first
        '/': (_) => const SplashScreen(),

        // Auth
        AppRoutes.login:   (_) => const LoginPage(),   // 👈 add this
        AppRoutes.profile: (_) => const ProfilePage(),
        AppRoutes.settings: (_) => const SettingsPage(),

        // Home
        AppRoutes.home: (_) => const Home(),

        // ===== Voitures =====
        AppRoutes.voituresList: (_) =>
            _wrap('Liste des voitures', AppRoutes.voituresList, const Listevoitures()),
        AppRoutes.voituresAdd: (_) =>
            _wrap('Ajouter voiture', AppRoutes.voituresAdd, const AjoutervoiturePage()),
        AppRoutes.voituresFluxAdd: (_) =>
            _wrap('Créer un flux', AppRoutes.voituresFluxAdd, const Creerflux()),
        AppRoutes.voitureDetails: (_) =>
            _wrap('Détails voiture', AppRoutes.voituresList, const CarDetailsPage()),
        AppRoutes.voituresEdit: (_) =>
            _wrap('Modifier voiture', AppRoutes.voituresList, const VoitureEditPage()),
        AppRoutes.voituresFrais: (_) =>
            _wrap('Liste des frais', AppRoutes.voituresFrais, const FraisVoiturePage()),

        // ===== Paiements =====
     //   AppRoutes.paiements: (_) => const Paiementsmois(),
        AppRoutes.paiementsHistory: (_) => const PaiementsHistoryPage(),

        // ===== Chauffeurs =====
        AppRoutes.chauffeursList: (_) =>
            _wrap('Liste des chauffeurs', AppRoutes.chauffeursList, const ListeChauffeursPage()),
        AppRoutes.chauffeursAdd: (_) => const ChauffeursAddPage(),

        // ===== Sociétés =====
        AppRoutes.societesList: (_) =>
            _wrap('Liste des sociétés', AppRoutes.societesList, const Listesocietes()),
        AppRoutes.societesAdd: (_) =>
            _wrap('Ajouter société', AppRoutes.societesAdd, const Ajoutersociete()),

        // ===== Flux transport =====
        AppRoutes.voituresFluxDetail: (_) => const FluxDetailPage(),

        // ===== Missions =====
        AppRoutes.missionsCreate: (_) =>
            _wrap('Nouvel ordre de mission', AppRoutes.missionsCreate, const OrdreMissionFormPage()),
        // AppRoutes.missionsList: (_) =>
        //     _wrap('Liste des missions', AppRoutes.missionsList, const MissionsListPage()),

        AppRoutes.superAdminAddAdmin: (_) => const AddAdminPage(),

        AppRoutes.superDocordremision: (_) => const Docordremision(),


      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => _wrap('Route inconnue', '', const SizedBox.shrink()),
      ),
    );
  }
}


Widget _page(String title, String activeRoute) {
  final sections = AppMenu.buildDefaultSections(
  );

  return LayoutBuilder(
    builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 980;
      void go(String r) => Navigator.of(context).pushReplacementNamed(r);

      final content = Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF121214).withOpacity(.35),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(title, style: const TextStyle(fontSize: 20, color: Colors.white)),
        ),
      );

      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: isWide
            ? null
            : AppBarWithMenu(
          title: title,
          sections: sections,
          activeRoute: activeRoute,
          onNavigate: (r) {
            Navigator.of(context).pop(); // ferme le Drawer
            go(r);
          },
        ),
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
        body: SafeArea(
          child: isWide
              ? Row(
            children: [
              SizedBox(
                width: 260,
                child: AppSideMenu(
                  activeRoute: activeRoute,
                  sections: sections,
                  onNavigate: go,
                ),
              ),
              const VerticalDivider(width: 0, color: Colors.transparent),
              Expanded(child: content),
            ],
          )
              : content,
        ),
      );
    },
  );
}


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _showLogin = false;

  static const Color kOrange = Color(0xFFE4631D);
  static const Color kBg1 = Color(0xFF0C0C0D);
  static const Color kBg2 = Color(0xFF151517);

  @override
  void initState() {
    super.initState();
    _precacheImages();
    _setupAnimations();
    _startAnimationSequence();
  }

  Future<void> _precacheImages() async {
    await Future.wait([
      precacheImage(const AssetImage('assets/images/f24aad88-ac52-4ecf-9556-3923fadb60b5.png'), context),
      precacheImage(const AssetImage('assets/images/3c06a6eb-e895-4e7b-971d-2c11dba223c0.png'), context),
    ]);
  }

  void _setupAnimations() {
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _slideAnimation = Tween<Offset>(begin: const Offset(3.9, 0), end: const Offset(-4.0, 0))
        .animate(CurvedAnimation(parent: _controller, curve: const Interval(0.5, 0.8, curve: Curves.easeInOut)));
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _controller, curve: const Interval(0.8, 1.0, curve: Curves.easeOut)));
  }

  void _startAnimationSequence() {
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _controller.forward().then((_) async {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) setState(() => _showLogin = true);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [kBg1, kBg2],
              ),
            ),
          ),
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [kOrange.withOpacity(.28), Colors.transparent]),
              ),
            ),
          ),
          Positioned(
            bottom: -120, left: -80,
            child: Container(
              width: 340, height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [kOrange.withOpacity(.22), Colors.transparent]),
              ),
            ),
          ),
          Center(
            child: AnimatedOpacity(
              opacity: _showLogin ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 500),
              child: Image.asset(
                'assets/images/f24aad88-ac52-4ecf-9556-3923fadb60b5.png',
                width: 200, height: 300, fit: BoxFit.contain, color: kOrange,
              ),
            ),
          ),
          if (!_showLogin)
            Center(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Image.asset(
                    'assets/images/3c06a6eb-e895-4e7b-971d-2c11dba223c0.png',
                    width: 240, height: 250, fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          AnimatedOpacity(
            opacity: _showLogin ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 800),
            child: _showLogin ? const LoginPage() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _cinController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  late final AnimationController _haloCtrl;
  late final Animation<double> _haloOpacity;
  bool _reveal = false;
  bool _vanInPlace = false;

  static const Color kOrange = Color(0xFFE4631D);
  static const Color kBg1 = Color(0xFF0C0C0D);
  static const Color kBg2 = Color(0xFF151517);
  static const Color kCard = Color(0xFF121214);
  static const Color kBorder = Color(0xFF2A2A2E);
  static const Color kHint = Color(0xFF8A8A90);

  @override
  void initState() {
    super.initState();
    _haloCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _haloOpacity = CurvedAnimation(parent: _haloCtrl, curve: Curves.easeInOut)
        .drive(Tween(begin: 0.18, end: 0.38));

    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _reveal = true);
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) setState(() => _vanInPlace = true);
      });
    });
  }

  @override
  void dispose() {
    _haloCtrl.dispose();
    _cinController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidCin(String v) => v.trim().isNotEmpty && v.trim().length >= 6;

  // === LOGIN ===
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final remote = AuthRemote();
      final repo = AuthRepository(remote);

      final cin = _cinController.text.trim();
      final pwd = _passwordController.text;

      final resp = await repo.login(cin, pwd);
      final u = resp.user;

      if (u == null) {
        throw const FormatException("L'utilisateur n'a pas pu être récupéré");
      }

      // ✅ Save useful info in cache
      await CacheHelper.saveData(key: 'token', value: resp.token);
      await CacheHelper.saveData(key: 'user', value: jsonEncode(u.toJson()));

      // ✅ Save individual fields (for convenience)
      await CacheHelper.saveData(key: 'userId', value: u.id);
      await CacheHelper.saveData(key: 'userName', value: u.nomComplet ?? 'Utilisateur'); // 👈 important
      await CacheHelper.saveData(key: 'nomComplet', value: u.nomComplet ?? 'Utilisateur');
      await CacheHelper.saveData(key: 'email', value: u.email ?? '');
      await CacheHelper.saveData(key: 'telephone', value: u.telephone ?? '');
      await CacheHelper.saveData(key: 'cin', value: u.cin ?? '');
      await CacheHelper.saveData(key: 'role', value: u.role ?? '');
      await CacheHelper.saveData(key: 'societeId', value: u.societeId ?? 0);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PostLoginTransition()),
      );

    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Réponse inattendue: ${e.message}')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      String msg = 'Erreur réseau';
      final data = e.response?.data;
      if (data is Map && data['message'] != null) msg = data['message'].toString();
      else if (data is String && data.trim().isNotEmpty) msg = data;
      else if (e.message != null) msg = e.message!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _decor({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: kHint),
      labelStyle: const TextStyle(color: kHint),
      prefixIcon: Icon(icon, color: kHint),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF1A1A1E),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kOrange, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kBg1, kBg2],
              ),
            ),
          ),
          // --- Effet Halo (non modifié) ---
          Positioned(
            top: -80,
            right: -60,
            child: AnimatedBuilder(
              animation: _haloOpacity,
              builder: (_, __) => Opacity(
                opacity: _haloOpacity.value,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                    RadialGradient(colors: [kOrange, Colors.transparent]),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: AnimatedBuilder(
              animation: _haloOpacity,
              builder: (_, __) => Opacity(
                opacity: _haloOpacity.value * 0.9,
                child: Container(
                  width: 340,
                  height: 340,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                    RadialGradient(colors: [kOrange, Colors.transparent]),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Card(
                    color: kCard,
                    elevation: 10,
                    shadowColor: Colors.black.withOpacity(.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: const BorderSide(color: kBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(36, 36, 36, 28),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnimatedSlide(
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutBack,
                              offset: _vanInPlace
                                  ? Offset.zero
                                  : const Offset(-.25, 0),
                              child: CircleAvatar(
                                radius: 90,
                                backgroundColor: const Color(0xFF1E1E22),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Image.asset(
                                    'assets/images/fa255587-6402-42e0-a7df-b72b9f6f9e69.png',
                                    height: 400,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Divider(
                                height: 1,
                                color: Colors.white.withOpacity(.06)),
                            const SizedBox(height: 22),
                            TextFormField(
                              controller: _cinController,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(color: Colors.white),
                              decoration: _decor(
                                label: 'CIN',
                                hint: 'Entrez votre CIN',
                                icon: Icons.badge_outlined,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Veuillez entrer votre CIN';
                                if (!_isValidCin(v)) return 'CIN invalide';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) =>
                              _isLoading ? null : _submit(),
                              style: const TextStyle(color: Colors.white),
                              decoration: _decor(
                                label: 'Mot de passe',
                                hint: 'Entrez votre mot de passe',
                                icon: Icons.lock_outline,
                                suffix: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Afficher'
                                      : 'Masquer',
                                  icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: kHint),
                                  onPressed: () => setState(
                                          () => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Veuillez entrer votre mot de passe';
                                if (v.length < 6)
                                  return 'Le mot de passe doit contenir au moins 6 caractères';
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 48,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: kOrange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(12)),
                                ),
                                onPressed: _isLoading ? null : _submit,
                                child: _isLoading
                                    ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                                    : const Text('Se connecter',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.center,
                              child: Wrap(
                                crossAxisAlignment:
                                WrapCrossAlignment.center,
                                children: const [
                                  Text('Mot de passe oublié ? ',
                                      style:
                                      TextStyle(color: Colors.white70)),
                                  Text('Réinitialiser',
                                      style: TextStyle(
                                          color: kOrange,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
