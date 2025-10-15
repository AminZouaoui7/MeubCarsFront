import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:meubcars/core/cache/cacheHelper.dart';
import 'package:meubcars/core/api/endpoints.dart';
import 'package:meubcars/utils/AppSideMenu.dart';

class RequireAuth extends StatelessWidget {
  final String targetRouteName;
  final Widget child;
  const RequireAuth({super.key, required this.targetRouteName, required this.child});

  Future<bool> _isLoggedInAndValid() async {
    // 1) token
    final raw = CacheHelper.getData(key: 'token');
    final t = (raw ?? '').toString().trim();
    if (t.isEmpty || t.toLowerCase() == 'null' || t == '0') {
      debugPrint('🔒 RequireAuth: pas de token');
      return false;
    }

    // 2) exp JWT locale
    final parts = t.split('.');
    if (parts.length == 3) {
      try {
        final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
        final exp = payload['exp'];
        if (exp is int) {
          final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          if (exp <= nowSec) {
            debugPrint('🔒 RequireAuth: token expiré localement');
            return false;
          }
        }
      } catch (_) {
        // ignore -> on validera via backend
      }
    }

    // 3) ping backend
    final dio = Dio(BaseOptions(
      baseUrl: EndPoint.baseUrl, // ex: https://meubcars-api.onrender.com/api/
      connectTimeout: const Duration(seconds: 8),
    ));
    try {
      debugPrint('🔒 RequireAuth: ping ${EndPoint.baseUrl}auth/me');
      final r = await dio.get(
        'auth/me', // ✅ minuscule
        options: Options(headers: {'Authorization': 'Bearer $t', 'Accept': 'application/json'}),
      );
      debugPrint('🔒 RequireAuth: status=${r.statusCode}');
      return r.statusCode == 200;
    } on DioException catch (e) {
      final sc = e.response?.statusCode ?? 0;
      debugPrint('🔒 RequireAuth: DioException status=$sc ${e.message}');
      if (sc == 401 || sc == 403) return false;
      return false;
    } catch (e) {
      debugPrint('🔒 RequireAuth: erreur $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedInAndValid(),
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
        return child;
      },
    );
  }
}
