import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class Motion {
  static const Duration xShort = Duration(milliseconds: 120);
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration long = Duration(milliseconds: 500);
  static const Duration xLong = Duration(milliseconds: 800);

  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;

  static const int baseStagger = 60; // ms per item for list staggers

  static Tween<double> fadeInTween({double begin = 0, double end = 1}) =>
      Tween(begin: begin, end: end);
  static Tween<double> scaleTween({double begin = 0.98, double end = 1}) =>
      Tween(begin: begin, end: end);
  static Tween<Offset> slideYTween({double begin = 0.2, double end = 0}) =>
      Tween(begin: Offset(0, begin), end: Offset.zero);
}

Page<void> buildTransitionPage({required Widget child}) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: Motion.medium,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = Motion.fadeInTween()
          .animate(CurvedAnimation(parent: animation, curve: Motion.easeInOut));
      final scale = Motion.scaleTween().animate(
          CurvedAnimation(parent: animation, curve: Motion.fastOutSlowIn));
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}

/// Extensions for consistent Flutter Animate effects
extension AnimateExtension<T> on Animate {
  Animate premiumFade({Duration? delay}) =>
      fadeIn(duration: Motion.medium, curve: Motion.easeOut, delay: delay);

  Animate premiumSlide({Duration? delay, double begin = 0.1}) => slideY(
      begin: begin,
      duration: Motion.medium,
      curve: Motion.easeOut,
      delay: delay);

  Animate premiumScale({Duration? delay}) => scale(
      begin: const Offset(0.95, 0.95),
      duration: Motion.medium,
      curve: Motion.fastOutSlowIn,
      delay: delay);
}
