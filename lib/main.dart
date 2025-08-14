import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_in_app_pip/flutter_in_app_pip.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'config/router/app_router.dart';
import 'config/theme/app_theme.dart';
import 'presentation/providers/theme/theme_provider.dart';

Future<void> main() async {
  FlutterNativeSplash.preserve(
      widgetsBinding: WidgetsFlutterBinding.ensureInitialized());

  // Configurar URL strategy para web (eliminar hash #)
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Cargar variables de entorno con manejo de errores
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // En web, el archivo .env puede no estar disponible en producción
    if (kDebugMode) {
      print('Error loading .env file: $e');
    }
  }

  // INICIALIZAR ADMOB solo en plataformas móviles
  if (!kIsWeb) {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing MobileAds: $e');
      }
    }
  }

  // Habilitar edge-to-edge para Android 15 (SDK 35)
  if (!kIsWeb) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    initializeDateFormatting();
    
    // Remover el splash screen después de que el primer frame esté construido
    // En web, usar un enfoque más robusto
    if (kIsWeb) {
      // Para web, remover inmediatamente o usar un timer
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          FlutterNativeSplash.remove();
        } catch (e) {
          if (kDebugMode) {
            print('Error removing splash screen: $e');
          }
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          FlutterNativeSplash.remove();
        } catch (e) {
          if (kDebugMode) {
            print('Error removing splash screen: $e');
          }
        }
      });
    }
    final AppTheme appTheme = ref.watch(themeNotifierProvider.select(
      (theme) => AppTheme(
        selectedColor: theme.selectedColor,
        isDarkMode: theme.isDarkMode,
      ),
    ));

    // Usar MaterialApp regular para web para evitar problemas de compatibilidad
    if (kIsWeb) {
      return MaterialApp.router(
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
        theme: appTheme.getTheme(),
      );
    }
    
    return PiPMaterialApp.router(
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      theme: appTheme.getTheme(),
      pipParams: PiPParams(
        pipWindowHeight: 200,
        pipWindowWidth: 300,
        bottomSpace: 80,
        leftSpace: 16,
        rightSpace: 16,
        topSpace: 80,
        movable: true,
        resizable: false,
        initialCorner: PIPViewCorner.bottomRight,
      ),
    );
  }
}
