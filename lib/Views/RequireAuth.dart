import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:meubcars/core/cache/cacheHelper.dart';

class RequireAuth extends StatelessWidget {
  final String targetRouteName;
  final Widget child;

  const RequireAuth({
    super.key,
    required this.targetRouteName,
    required this.child,
  });

  Future<bool> _isLoggedInAndValid() async {
    final raw = CacheHelper.getData(key: 'token');
    final token = (raw ?? '').toString().trim();
    if (token.isEmpty) return false;

    try {
      if (JwtDecoder.isExpired(token)) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedInAndValid(),
      builder: (context, snap) {
        // 1️⃣ While checking, show loader
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2️⃣ Not logged in → redirect immediately to login
        if (snap.data != true) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await CacheHelper.clearData();
            if (context.mounted) {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (r) => false);
            }
          });
          return const SizedBox.shrink();
        }

        // 3️⃣ Logged in → render protected page
        return child;
      },
    );
  }
}
