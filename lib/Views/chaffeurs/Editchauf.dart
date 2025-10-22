// lib/Views/chauffeurs/editchauf.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:meubcars/core/cache/CacheHelper.dart';
import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/utils/AppSideMenu.dart'; // AppRoutes, AppMenu, AppSideMenu, AppColors
import 'package:meubcars/utils/AppBar.dart';      // AppBarWithMenu

/// petit modèle Id/Label
class _IdLabel {
  final int id;
  final String label;
  const _IdLabel(this.id, this.label);
  @override
  String toString() => label;
}

class Editchauf extends StatefulWidget {
  final int id;
  const Editchauf({super.key, required this.id});

  @override
  State<Editchauf> createState() => _EditchaufState();
}

class _EditchaufState extends State<Editchauf> {
  // HTTP
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

  // Form
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _cinCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController(); // optionnel en édition

  bool _loading = true;
  bool _submitting = false;

  // Sociétés
  List<_IdLabel> _societes = <_IdLabel>[];
  int? _selectedSocieteId;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _cinCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
    });
    try {
      await Future.wait([_loadSocietes(), _loadUser()]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSocietes() async {
    try {
      final headers = await _authHeaders();
      final r = await _dio.get('Societes', options: Options(headers: headers));
      final data = r.data;
      if (data is List) {
        final items = <_IdLabel>[];
        for (final e in data) {
          if (e is Map) {
            final id = int.tryParse('${e['id'] ?? e['Id'] ?? ''}');
            final nom = '${e['nom'] ?? e['Nom'] ?? ''}';
            if (id != null) items.add(_IdLabel(id, nom.isEmpty ? 'Société #$id' : nom));
          }
        }
        _societes = items;
      }
    } catch (_) {/* ignore */}
  }

  Future<void> _loadUser() async {
    try {
      final headers = await _authHeaders();
      final r = await _dio.get('Utilisateurs/${widget.id}', options: Options(headers: headers));
      final m = (r.data as Map);

      _nomCtrl.text = '${m['nomComplet'] ?? m['NomComplet'] ?? ''}';
      _emailCtrl.text = '${m['email'] ?? m['Email'] ?? ''}';
      _telCtrl.text = '${m['telephone'] ?? m['Telephone'] ?? ''}';
      _cinCtrl.text = '${m['cin'] ?? m['Cin'] ?? ''}';
      final sid = m['societeId'] ?? m['SocieteId'];
      _selectedSocieteId = sid == null ? null : int.tryParse('$sid');
      setState(() {});
    } on DioException catch (e) {
      _toast(e.response?.data?.toString() ?? e.message ?? 'Erreur de chargement');
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final headers = await _authHeaders();
      final body = {
        'nomComplet': _nomCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'telephone': _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
        'cin': _cinCtrl.text.trim(),
        'role': 2,                         // Chauffeur forcé
        'societeId': _selectedSocieteId,
      };
      if (_pwdCtrl.text.trim().isNotEmpty) {
        body['password'] = _pwdCtrl.text;
      }

      final r = await _dio.put(
        'Utilisateurs/${widget.id}',
        data: body,
        options: Options(headers: headers),
      );
      if (r.statusCode == 204) {
        _toast('Chauffeur modifié.');
        if (mounted) Navigator.of(context).pop(); // retour à la liste
      } else {
        _toast('Mise à jour non confirmée (${r.statusCode}).');
      }
    } on DioException catch (e) {
      _toast(e.response?.data?.toString() ?? e.message ?? 'Erreur réseau');
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = AppMenu.buildDefaultSections(
      hasPaiementAlerts: () => true,
    );
    void go(String r) => Navigator.of(context).pushReplacementNamed(r);

    return LayoutBuilder(builder: (context, c) {
      final isWide = c.maxWidth >= 980;

      final content = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Modifier le chauffeur',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.kBg3,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 8, offset: const Offset(0,4))],
                ),
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white70))
                    : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Formulaire d\'édition',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 20),

                        _field(controller: _nomCtrl, label: 'Nom complet *', icon: Icons.person_outline,
                          validator: (v) => (v == null || v.trim().length < 3) ? 'Nom trop court' : null,
                        ),
                        const SizedBox(height: 14),

                        _field(controller: _emailCtrl, label: 'Email', icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return null;
                            final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);
                            return ok ? null : 'Email invalide';
                          },
                        ),
                        const SizedBox(height: 14),

                        _field(controller: _telCtrl, label: 'Téléphone', icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),

                        _field(controller: _cinCtrl, label: 'CIN *', icon: Icons.badge_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return 'CIN requis';
                            if (s.length < 6) return 'CIN trop court';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        _field(controller: _pwdCtrl,
                          label: 'Mot de passe (laisser vide pour conserver)',
                          icon: Icons.lock_outline,
                          obscureText: true,
                        ),
                        const SizedBox(height: 14),

                        _societeDropdown(),
                        const SizedBox(height: 24),

                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_outlined),
                            label: Text(_submitting ? 'Enregistrement...' : 'Enregistrer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.kOrange,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      return Scaffold(
        backgroundColor: AppColors.kBg1,
        appBar: isWide
            ? null
            : AppBarWithMenu(
          title: 'Modifier chauffeur',
          sections: sections,
          activeRoute: AppRoutes.chauffeursAdd, // n.b. pas critique pour l’édition
          onNavigate: (r) { Navigator.of(context).pop(); go(r); },
          onHomePressed: () => go('/'),
        ),
        drawer: isWide
            ? null
            : Drawer(
          width: MediaQuery.of(context).size.width * .8,
          child: AppSideMenu(
            activeRoute: AppRoutes.chauffeursAdd,
            sections: sections,
            onNavigate: (r) { Navigator.of(context).pop(); go(r); },
          ),
        ),
        body: SafeArea(
          child: isWide
              ? Row(
            children: [
              AppSideMenu(
                activeRoute: AppRoutes.chauffeursAdd,
                sections: sections,
                onNavigate: go,
              ),
              Expanded(child: content),
            ],
          )
              : content,
        ),
      );
    });
  }

  // ---- widgets ----
  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.onDark60),
        prefixIcon: Icon(icon, color: AppColors.onDark60),
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
    );
  }

  Widget _societeDropdown() {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Aucune', style: TextStyle(color: Colors.white)),
      ),
      ..._societes.map((s) => DropdownMenuItem<int?>(
        value: s.id,
        child: Text(s.label, style: const TextStyle(color: Colors.white)),
      )),
    ];

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Société (optionnel)',
        labelStyle: TextStyle(color: AppColors.onDark60),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.onDark40),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.kOrange),
        ),
        filled: true,
        fillColor: AppColors.kBg2,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          isExpanded: true,
          value: _selectedSocieteId,
          items: items,
          dropdownColor: AppColors.kBg2,
          iconEnabledColor: Colors.white70,
          onChanged: (v) => setState(() => _selectedSocieteId = v),
        ),
      ),
    );
  }
}
