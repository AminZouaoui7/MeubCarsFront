import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:meubcars/core/cache/cacheHelper.dart';
import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/background.dart';
import 'package:meubcars/Data/Models/user_model.dart';
import 'package:meubcars/Data/repositories/auth_repository.dart';
import 'package:meubcars/Data/remote/auth_remote.dart';

class AddAdminPage extends StatefulWidget {
  const AddAdminPage({super.key});

  @override
  State<AddAdminPage> createState() => _AddAdminPageState();
}

class _AddAdminPageState extends State<AddAdminPage> {
  // === Repos pour l'utilisateur connecté ===
  final AuthRepository _authRepo = AuthRepository(AuthRemote());
  Future<UserModel?>? _userF;

  // === HTTP ===
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

  // === Form ===
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _cinController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _userF = _authRepo.getCachedUser();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _cinController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _closeDrawerIfOpen() {
    FocusScope.of(context).unfocus();
    final s = Scaffold.maybeOf(context);
    if (s?.isDrawerOpen ?? false) Navigator.of(context).pop();
  }

  void _go(String route) {
    _closeDrawerIfOpen();
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final headers = await _authHeaders();

      final data = {
        "nomComplet": _nomController.text.trim(),
        "email": _emailController.text.trim(),
        "telephone": _telephoneController.text.trim(),
        "cin": _cinController.text.trim(),
        "password": _passwordController.text.trim(),
        "role": "Admin",
      };

      final r = await _dio.post(
        'Utilisateurs',
        data: data,
        options: Options(headers: headers),
      );

      if (r.statusCode == 200 || r.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Administrateur ajouté avec succès ✅")),
        );
        _formKey.currentState?.reset();
      } else {
        throw Exception("Erreur ${r.statusCode}: ${r.data}");
      }
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data?.toString() ?? e.message ?? 'Erreur réseau')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeNow =
        ModalRoute.of(context)?.settings.name ?? AppRoutes.superAdminAddAdmin;

    return FutureBuilder<UserModel?>(
      future: _userF,
      builder: (_, snap) {
        final user = snap.data;

        final sections = AppMenu.buildDefaultSections(
          role: user?.role,

          hasPaiementAlerts: () => true,
        );

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBarWithMenu(
            title: "Ajouter un administrateur",
            onNavigate: _go,
            currentUser: user,
          ),
          drawer: AppSideMenu(
            activeRoute: routeNow,
            sections: sections,
            onNavigate: _go,
          ),
          body: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _closeDrawerIfOpen(),
            onPointerSignal: (_) => _closeDrawerIfOpen(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const BrandBackground(),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Card(
                          color: const Color(0xFF121214).withOpacity(.7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.kBg3),
                          ),
                          elevation: 8,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Formulaire de création d’un nouvel administrateur",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildField(
                                    controller: _nomController,
                                    label: "Nom complet",
                                    icon: Icons.person_outline,
                                    validator: (v) => v == null || v.isEmpty
                                        ? "Veuillez entrer un nom"
                                        : null,
                                  ),
                                  _buildField(
                                    controller: _emailController,
                                    label: "Email",
                                    icon: Icons.email_outlined,
                                    validator: (v) => v == null || v.isEmpty
                                        ? "Veuillez entrer un email"
                                        : null,
                                  ),
                                  _buildField(
                                    controller: _telephoneController,
                                    label: "Téléphone",
                                    icon: Icons.phone_outlined,
                                  ),
                                  _buildField(
                                    controller: _cinController,
                                    label: "CIN",
                                    icon: Icons.credit_card_outlined,
                                  ),
                                  _buildField(
                                    controller: _passwordController,
                                    label: "Mot de passe",
                                    icon: Icons.lock_outline,
                                    obscure: true,
                                    validator: (v) =>
                                    (v == null || v.length < 4)
                                        ? "Mot de passe trop court"
                                        : null,
                                  ),
                                  const SizedBox(height: 32),
                                  Center(
                                    child: FilledButton.icon(
                                      icon: _isLoading
                                          ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2),
                                      )
                                          : const Icon(Icons.save),
                                      label: Text(
                                        _isLoading
                                            ? "En cours..."
                                            : "Créer l’administrateur",
                                      ),
                                      onPressed: _isLoading ? null : _submit,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.kOrange,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 14),
                                        textStyle: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
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
          ),
        );
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF1A1A1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.kBg3),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.kBg3),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: AppColors.kOrange, width: 1.4),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        validator: validator,
      ),
    );
  }
}
