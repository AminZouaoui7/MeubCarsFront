import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:meubcars/core/cache/CacheHelper.dart';

class RequireAuth extends StatelessWidget {
  final Widget child;
  final String routeName; // ex: AppRoutes.home

  const RequireAuth({super.key, required this.child, required this.routeName});

  bool _hasValidToken() {
    final t = CacheHelper.getData<String>(key: 'token');
    if (t == null || t.trim().isEmpty) return false;
    try {
      return !JwtDecoder.isExpired(t);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidToken()) {
      Future.microtask(() {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
              (r) => false,
          arguments: {'from': routeName},
        );
      });
      return const SizedBox.shrink();
    }
    return child;
  }
}
