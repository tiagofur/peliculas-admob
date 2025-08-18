import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// ScrollBehavior personalizado para habilitar drag scrolling en web
class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}
