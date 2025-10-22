// lib/PostLoginTransition.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:meubcars/utils/AppSideMenu.dart'; // pour AppRoutes

class PostLoginTransition extends StatefulWidget {
  const PostLoginTransition({super.key});

  @override
  State<PostLoginTransition> createState() => _PostLoginTransitionState();
}

class _PostLoginTransitionState extends State<PostLoginTransition>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<Offset>? _slide;
  Animation<double>? _fade;
  bool _done = false;

  static const kOrange = Color(0xFFE4631D);
  static const kBg1 = Color(0xFF0C0C0D);
  static const kBg2 = Color(0xFF151517);

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  Future<void> _initAnimations() async {
    try {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      );

      _slide = Tween<Offset>(
        begin: const Offset(3.9, 0),
        end: const Offset(-4.0, 0),
      ).animate(
        CurvedAnimation(
          parent: _ctrl!,
          curve: const Interval(.25, .75, curve: Curves.easeInOut),
        ),
      );

      _fade = Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(
          parent: _ctrl!,
          curve: const Interval(.70, 1.0, curve: Curves.easeOut),
        ),
      );

      // 🔹 Démarre la séquence d'animation et navigation
      await Future.delayed(const Duration(milliseconds: 600));
      await _ctrl?.forward();

      if (!mounted) return;
      setState(() => _done = true);

      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _goHome();
    } catch (e) {
      debugPrint('⚠️ AnimationController init failed: $e');
      _goHome(); // fallback direct
    }
  }

  void _goHome() {
    try {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (r) => false);
    } catch (e) {
      debugPrint('⚠️ Navigation error in PostLoginTransition: $e');
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      }
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slideAnim = _slide ?? const AlwaysStoppedAnimation(Offset.zero);
    final fadeAnim = _fade ?? const AlwaysStoppedAnimation(1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kBg1, kBg2],
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x46E4631D), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x36E4631D), Colors.transparent],
                ),
              ),
            ),
          ),
          // 🔶 Premier logo fade out
          Center(
            child: AnimatedOpacity(
              opacity: _done ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 400),
              child: Image.asset(
                'assets/images/f24aad88-ac52-4ecf-9556-3923fadb60b5.png',
                width: 200,
                height: 300,
                fit: BoxFit.contain,
                color: kOrange,
              ),
            ),
          ),
          // 🔶 Deuxième logo animé
          if (!_done)
            Center(
              child: SlideTransition(
                position: slideAnim,
                child: FadeTransition(
                  opacity: fadeAnim,
                  child: Image.asset(
                    'assets/images/3c06a6eb-e895-4e7b-971d-2c11dba223c0.png',
                    width: 240,
                    height: 250,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
