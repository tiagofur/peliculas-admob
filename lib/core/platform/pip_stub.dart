// Stub para flutter_in_app_pip en plataformas web
import 'package:flutter/material.dart';

// Enum stub para PIPViewCorner
enum PIPViewCorner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

// Clase stub para PiPParams
class PiPParams {
  const PiPParams({
    required this.pipWindowHeight,
    required this.pipWindowWidth,
    required this.bottomSpace,
    required this.leftSpace,
    required this.rightSpace,
    required this.topSpace,
    required this.movable,
    required this.resizable,
    required this.initialCorner,
  });
  final double pipWindowHeight;
  final double pipWindowWidth;
  final double bottomSpace;
  final double leftSpace;
  final double rightSpace;
  final double topSpace;
  final bool movable;
  final bool resizable;
  final PIPViewCorner initialCorner;
}

// Clase stub para PiPMaterialApp que actúa como MaterialApp normal
class PiPMaterialApp extends MaterialApp {
  const PiPMaterialApp.router({
    super.key,
    required super.routerConfig,
    super.debugShowCheckedModeBanner,
    super.theme,
    super.darkTheme,
    super.themeMode,
    super.locale,
    super.localizationsDelegates,
    super.supportedLocales,
    super.builder,
    PiPParams? pipParams, // Ignorado en web
  }) : super.router();
}
