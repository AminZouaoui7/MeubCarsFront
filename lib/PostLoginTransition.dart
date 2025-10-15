// Post-login brand transition (rejoue l'anim Splash puis va vers Home)
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meubcars/Views/Home.dart';

class PostLoginTransition extends StatefulWidget {
  const PostLoginTransition({super.key});

  // si tu veux l’utiliser aussi pour d’autres destinations:
  // final Widget next;
  // const PostLoginTransition({super.key, required this.next});

  @override
  State<PostLoginTransition> createState() => _PostLoginTransitionState();
}

class _PostLoginTransitionState extends State<PostLoginTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  bool _done = false;

  // même palette que Splash/Login
  static const kOrange = Color(0xFFE4631D);
  static const kBg1 = Color(0xFF0C0C0D);
  static const kBg2 = Color(0xFF151517);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));

    _slide = Tween<Offset>(
      begin: const Offset(3.9, 0),
      end: const Offset(-4.0, 0),
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(.25, .75, curve: Curves.easeInOut),
    ));

    _fade = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(.70, 1.0, curve: Curves.easeOut),
    ));

    _start();
  }

  Future<void> _start() async {
    // petit temps d’affichage du mot
    await Future.delayed(const Duration(milliseconds: 600));
    await _ctrl.forward();

    if (!mounted) return;

    // on navigue vers Home après l’anim
    setState(() => _done = true);
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const Home()),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // fond dégradé + halos
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [kBg1, kBg2],
              ),
            ),
          ),
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [kOrange.withOpacity(.28), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120, left: -80,
            child: Container(
              width: 340, height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [kOrange.withOpacity(.22), Colors.transparent],
                ),
              ),
            ),
          ),

          // mot "meubcars"
          Center(
            child: AnimatedOpacity(
              opacity: _done ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 400),
              child: Image.asset(
                'assets/images/f24aad88-ac52-4ecf-9556-3923fadb60b5.png',
                width: 200, height: 300, fit: BoxFit.contain, color: kOrange,
              ),
            ),
          ),

          // van qui traverse + fade
          if (!_done)
            Center(
              child: SlideTransition(
                position: _slide,
                child: FadeTransition(
                  opacity: _fade,
                  child: Image.asset(
                    'assets/images/3c06a6eb-e895-4e7b-971d-2c11dba223c0.png',
                    width: 240, height: 250, fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
