import 'package:flutter/material.dart';

class SpotlightClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Top is narrower
    path.moveTo(size.width * 0.25, 0);
    path.lineTo(size.width * 0.75, 0);
    // Bottom is wider
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
