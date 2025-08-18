import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_in_app_pip/flutter_in_app_pip.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/constants/environment.dart';
import 'config/router/app_router.dart';
import 'config/theme/app_theme.dart';
import 'config/theme/custom_scroll_behavior.dart';
import 'core/config/supabase_config.dart';
import 'presentation/providers/theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Solo preservar splash screen en plataformas móviles
  if (!kIsWeb) {
    FlutterNativeSplash.preserve(
        widgetsBinding: WidgetsFlutterBinding.ensureInitialized());
  }

  // Configurar URL strategy para web (eliminar hash #)
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  await Environment.load();

  // INICIALIZAR SUPABASE
  await SupabaseConfig.initialize();

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

    // Remover el splash screen solo en plataformas móviles
    if (!kIsWeb) {
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
    
    // Usar el router provider con autenticación
    final router = ref.watch(appRouterProvider);

    // Usar MaterialApp regular para web para evitar problemas de compatibilidad
    if (kIsWeb) {
      return ScrollConfiguration(
        behavior: CustomScrollBehavior(),
        child: MaterialApp.router(
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          theme: appTheme.getTheme(),
        ),
      );
    }

    return PiPMaterialApp.router(
      routerConfig: router,
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
