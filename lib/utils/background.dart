import 'package:flutter/material.dart';

class BrandBackground extends StatelessWidget {
  const BrandBackground({super.key});

  static const Color kOrange = Color(0xFFE4631D);
  static const Color kBg1 = Color(0xFF0C0C0D);
  static const Color kBg2 = Color(0xFF151517);

  @override
  Widget build(BuildContext context) {
    return Stack(
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [kOrange.withOpacity(.28), Colors.transparent],
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [kOrange.withOpacity(.22), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
