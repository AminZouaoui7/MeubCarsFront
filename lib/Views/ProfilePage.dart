import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:meubcars/Data/Models/user_model.dart';
import 'package:meubcars/Data/remote/auth_remote.dart';
import 'package:meubcars/Data/repositories/auth_repository.dart';
import 'package:meubcars/utils/AppBar.dart';
import 'package:meubcars/utils/AppSideMenu.dart';
import 'package:meubcars/core/cache/CacheHelper.dart';
import 'package:meubcars/utils/background.dart'; // ✅ import your BrandBackground

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _repo = AuthRepository(AuthRemote());
  Future<UserModel?>? _userF;

  @override
  void initState() {
    super.initState();
    _userF = Future<UserModel?>(() {
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is UserModel) return arg;
      final raw = CacheHelper.getData<String>(key: 'user');
      if (raw != null && raw.isNotEmpty) {
        return UserModel.fromJson(jsonDecode(raw));
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final routeNow = ModalRoute.of(context)?.settings.name ?? '/profile';
    final sections = AppMenu.buildDefaultSections(
    );

    void go(String r) {
      if (routeNow == r) return;
      Navigator.of(context).pushReplacementNamed(r);
    }

    return FutureBuilder<UserModel?>(
      future: _userF,
      builder: (_, snap) {
        final user = snap.data;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBarWithMenu(
            title: 'Profil',
            onNavigate: go,
            sections: sections,
            activeRoute: routeNow,
            currentUser: user,
          ),
          drawer: AppSideMenu(
            activeRoute: routeNow,
            sections: sections,
            onNavigate: go,
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              const BrandBackground(), // ✅ background
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 720),
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121214).withOpacity(.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: user == null
                      ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'Utilisateur introuvable.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.deepOrange,
                            child: Text(
                              user.nomComplet.isNotEmpty
                                  ? (user.nomComplet[0]).toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              user.nomComplet,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _tile('Email', user.email ?? '—'),
                      _tile('Téléphone', user.telephone ?? '—'),
                      _tile('CIN', user.cin),
                      _tile('Rôle', user.role),
                      _tile('Société ID',
                          user.societeId == null || user.societeId == 0
                              ? '—'
                              : user.societeId.toString()),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () {
                            // TODO: open edit profile
                          },
                          child: const Text('Modifier'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
