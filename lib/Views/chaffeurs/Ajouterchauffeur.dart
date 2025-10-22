// lib/Views/chauffeurs/ChauffeursAddPage.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:meubcars/core/cache/CacheHelper.dart';
import 'package:meubcars/Data/Models/user_model.dart';
import 'package:meubcars/Data/remote/auth_remote.dart';
import 'package:meubcars/Data/repositories/auth_repository.dart';
import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/background.dart';

class _IdLabel {
  final int id;
  final String label;
  const _IdLabel(this.id, this.label);
  @override
  String toString() => label;
}

class ChauffeursAddPage extends StatefulWidget {
  const ChauffeursAddPage({super.key});
  static const String route = AppRoutes.chauffeursAdd;

  @override
  State<ChauffeursAddPage> createState() => _ChauffeursAddPageState();
}

class _ChauffeursAddPageState extends State<ChauffeursAddPage> {
  // ===== HTTP =====
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

  // ===== USER =====
  final AuthRepository _authRepo = AuthRepository(AuthRemote());
  Future<UserModel?>? _userF;

  // ===== FORM =====
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _cinCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  DateTime? _dateEmbauche;

  bool _submitting = false;

  List<_IdLabel> _voitures = <_IdLabel>[];
  int? _selectedVoitureId;

  @override
  void initState() {
    super.initState();
    _userF = _authRepo.getCachedUser();
    _loadVoituresLibres();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _telCtrl.dispose();
    _cinCtrl.dispose();
    _adresseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVoituresLibres() async {
    try {
      final headers = await _authHeaders();
      final r = await _dio.get(
        'Voitures',
        options: Options(headers: headers),
      );
      if (r.data is List) {
        final items = <_IdLabel>[];
        for (final e in r.data) {
          if (e is Map) {
            final id = int.tryParse('${e['id'] ?? e['Id'] ?? ''}');
            final occupee = e['occupee'] == true;
            if (id != null && !occupee) {
              final mat = '${e['matricule'] ?? e['Matricule'] ?? ''}';
              final marque = '${e['marque'] ?? e['Marque'] ?? ''}';
              final modele = '${e['modele'] ?? e['Modele'] ?? ''}';
              items.add(_IdLabel(id, '$mat ($marque $modele)'));
            }
          }
        }
        setState(() => _voitures = items);
      }
    } catch (e) {
      _toast("Erreur lors du chargement des voitures: $e");
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVoitureId == null) {
      _toast("Veuillez sélectionner une voiture");
      return;
    }
    if (_dateEmbauche == null) {
      _toast("Veuillez choisir la date d'embauche");
      return;
    }

    setState(() => _submitting = true);
    try {
      final headers = await _authHeaders();
      final body = {
        "nom": _nomCtrl.text.trim(),
        "prenom": _prenomCtrl.text.trim(),
        "telephone": _telCtrl.text.trim(),
        "cin": _cinCtrl.text.trim(),
        "adresse": _adresseCtrl.text.trim(),
        "dateEmbauche": _dateEmbauche!.toIso8601String(),
        "voitureId": _selectedVoitureId
      };

      final r = await _dio.post(
        "Chauffeur",
        data: body,
        options: Options(headers: headers),
      );

      if (r.statusCode == 201 || r.statusCode == 200) {
        _toast("✅ Chauffeur ajouté avec succès !");
        _formKey.currentState!.reset();
        _selectedVoitureId = null;
        _nomCtrl.clear();
        _prenomCtrl.clear();
        _telCtrl.clear();
        _cinCtrl.clear();
        _adresseCtrl.clear();
        _dateEmbauche = null;
        setState(() {});
        _loadVoituresLibres(); // rafraîchir les voitures libres
      } else {
        _toast("Erreur ${r.statusCode}: ${r.data}");
      }
    } catch (e) {
      _toast("Erreur : $e");
    } finally {
      if (mounted) setState(() => _submitting = false);
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
    final routeNow =
        ModalRoute.of(context)?.settings.name ?? ChauffeursAddPage.route;

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
            title: 'Ajouter chauffeur',
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildForm(),
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

  Widget _buildForm() {
    return Card(
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
                'Formulaire d’ajout de chauffeur',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _field(
                controller: _nomCtrl,
                label: 'Nom *',
                icon: Icons.person_outline,
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              _field(
                controller: _prenomCtrl,
                label: 'Prénom *',
                icon: Icons.person_outline,
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Prénom requis' : null,
              ),
              _field(
                controller: _telCtrl,
                label: 'Téléphone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              _field(
                controller: _cinCtrl,
                label: 'CIN *',
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'CIN requis';
                  if (s.length < 6) return 'CIN trop court';
                  return null;
                },
              ),
              _field(
                controller: _adresseCtrl,
                label: 'Adresse',
                icon: Icons.home_outlined,
              ),
              const SizedBox(height: 16),
              _datePickerField(),
              const SizedBox(height: 16),
              _voitureDropdown(),
              const SizedBox(height: 32),
              Center(
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.save),
                  label: Text(
                      _submitting ? 'Ajout en cours...' : 'Ajouter le chauffeur'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.kOrange,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.onDark60),
          prefixIcon: Icon(icon, color: AppColors.onDark60),
          filled: true,
          fillColor: AppColors.kBg2,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.onDark40),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            const BorderSide(color: AppColors.kOrange, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _datePickerField() {
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: _dateEmbauche ?? now,
          firstDate: DateTime(now.year - 10),
          lastDate: DateTime(now.year + 2),
        );
        if (picked != null) setState(() => _dateEmbauche = picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: "Date d'embauche *",
          labelStyle: const TextStyle(color: AppColors.onDark60),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppColors.onDark40),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: AppColors.kOrange),
          ),
          filled: true,
          fillColor: AppColors.kBg2,
        ),
        child: Text(
          _dateEmbauche == null
              ? "Choisir une date"
              : "${_dateEmbauche!.day}/${_dateEmbauche!.month}/${_dateEmbauche!.year}",
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _voitureDropdown() {
    final items = _voitures.isEmpty
        ? [
      const DropdownMenuItem<int?>(
        value: null,
        child: Text("Aucune voiture disponible",
            style: TextStyle(color: Colors.white70)),
      )
    ]
        : _voitures
        .map((v) => DropdownMenuItem<int?>(
      value: v.id,
      child: Text(v.label,
          style: const TextStyle(color: Colors.white)),
    ))
        .toList();

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Voiture à affecter *',
        labelStyle: const TextStyle(color: AppColors.onDark60),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.onDark40),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.kOrange),
        ),
        filled: true,
        fillColor: AppColors.kBg2,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          isExpanded: true,
          value: _selectedVoitureId,
          items: items,
          dropdownColor: AppColors.kBg2,
          iconEnabledColor: Colors.white70,
          onChanged: (v) => setState(() => _selectedVoitureId = v),
        ),
      ),
    );
  }
}
