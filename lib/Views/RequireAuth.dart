import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:meubcars/core/cache/cacheHelper.dart';

class RequireAuth extends StatefulWidget {
  final String targetRouteName;
  final Widget child;

  const RequireAuth({
    super.key,
    required this.targetRouteName,
    required this.child,
  });

  @override
  State<RequireAuth> createState() => _RequireAuthState();
}

class _RequireAuthState extends State<RequireAuth> {
  bool _checked = false;
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = (CacheHelper.getData(key: 'token') ?? '').toString().trim();

    bool ok = false;
    if (token.isNotEmpty && !JwtDecoder.isExpired(token)) {
      ok = true;
    }

    if (!ok) {
      // Token missing or expired → redirect before building anything
      await CacheHelper.clearData();
      if (mounted) {
        // Replace with /login and clear navigation history
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      }
    }

    if (mounted) {
      setState(() {
        _authorized = ok;
        _checked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wait until check completes
    if (!_checked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If authorized → show page, else empty (since we redirected)
    return _authorized ? widget.child : const SizedBox.shrink();
  }
}
