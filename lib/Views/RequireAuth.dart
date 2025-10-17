// lib/Views/RequireAuth.dart
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:meubcars/core/cache/cacheHelper.dart';

class RequireAuth extends StatelessWidget {
  final Widget child;
  final String targetRouteName;

  const RequireAuth({
    super.key,
    required this.targetRouteName,
    required this.child,
  });

  Future<bool> _isLoggedInAndValid() async {
    final raw = CacheHelper.getData(key: 'token');
    final token = (raw ?? '').toString().trim();

    if (token.isEmpty || token == 'null' || token == '0') {
      return false;
    }

    try {
      if (JwtDecoder.isExpired(token)) {
        await _clearSession();
        return false;
      }
      return true;
    } catch (_) {
      await _clearSession();
      return false;
    }
  }

  Future<void> _clearSession() async {
    await CacheHelper.clearData();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedInAndValid(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isLoggedIn = snapshot.data ?? false;

        if (!isLoggedIn) {
          Future.microtask(() {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
                  (route) => false,
              arguments: {'from': targetRouteName},
            );
          });
          return const SizedBox.shrink();
        }

        return child;
      },
    );
  }
}
