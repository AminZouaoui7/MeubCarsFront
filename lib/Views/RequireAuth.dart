import 'package:flutter/material.dart';
import 'package:meubcars/core/cache/cacheHelper.dart';
import 'package:meubcars/utils/AppSideMenu.dart';

class RequireAuth extends StatelessWidget {
  final String targetRouteName;
  final Widget child;
  const RequireAuth({super.key, required this.targetRouteName, required this.child});

  Future<bool> _isLoggedIn() async {
    final raw = await CacheHelper.getData(key: 'token');
    final s = (raw ?? '').toString().trim();
    return s.isNotEmpty && s.toLowerCase() != 'null' && s != '0';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedIn(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data != true) {
          return Scaffold(
            body: Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Accès protégé', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text('Veuillez vous connecter pour accéder à cette page.', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed(
                            AppRoutes.login,
                            arguments: {'from': targetRouteName},
                          );
                        },
                        child: const Text('Se connecter'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return child; // ✅ connecté → on affiche la page protégée
      },
    );
  }
}
