import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
// Importar flutter_in_app_pip solo en plataformas nativas
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/constants/environment.dart';
import 'config/router/app_router.dart';
import 'config/theme/app_theme.dart' as app_theme;
import 'config/theme/custom_scroll_behavior.dart';
import 'core/config/supabase_config.dart';
import 'core/logging/logger_factory.dart';
import 'core/navigation/navigation_error_boundary.dart';
import 'core/state/app_state_restoration.dart';
import 'generated/app_localizations.dart';
import 'presentation/providers/locale/locale_provider.dart';
import 'presentation/providers/theme/theme_provider.dart';

// Simple Web App for debugging
class SimpleWebApp extends material.StatelessWidget {
  const SimpleWebApp({super.key});

  @override
  material.Widget build(material.BuildContext context) {
    return material.Scaffold(
      appBar: material.AppBar(
        title: const material.Text('Películas - Web Debug'),
      ),
      body: const material.Center(
        child: material.Column(
          mainAxisAlignment: material.MainAxisAlignment.center,
          children: [
            material.Icon(
              material.Icons.check_circle,
              color: material.Colors.green,
              size: 64,
            ),
            material.SizedBox(height: 16),
            material.Text(
              '¡Web App Funcionando!',
              style: material.TextStyle(
                fontSize: 24,
                fontWeight: material.FontWeight.bold,
              ),
            ),
            material.SizedBox(height: 8),
            material.Text(
              'Los servicios básicos están funcionando correctamente',
              textAlign: material.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Mantiene el splash screen visible hasta que la inicialización termine.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Configurar URL strategy para web (eliminar hash #)
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Inicializar servicios críticos ANTES de correr la app
  try {
    LoggerFactory.info('🚀 Initializing critical services...');

    await Environment.load();
    LoggerFactory.info('✅ Environment loaded');

    await SupabaseConfig.initialize();
    LoggerFactory.info('✅ Supabase initialized');

    if (!kIsWeb) {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      LoggerFactory.info('✅ Firebase initialized');
    }

    // Inicializar AdMob en segundo plano (no bloquear la app)
    if (!kIsWeb) {
      MobileAds.instance.initialize().then((_) {
        LoggerFactory.info('✅ MobileAds initialized');
      }).catchError((e) {
        LoggerFactory.error('❌ MobileAds failed: $e');
      });
    }

    LoggerFactory.info('✅ Critical services initialized. Launching app.');
  } catch (e, stackTrace) {
    LoggerFactory.reportCriticalError(
      e,
      stackTrace,
      context: 'Critical services initialization',
      fatal: true, // Es fatal si los servicios críticos fallan
    );
    // En un futuro, se podría mostrar una pantalla de error aquí.
  }

  // Iniciar la aplicación
  runApp(
    const ProviderScope(
      child: MainApp(),
    ),
  );
}

/// Convierte el ThemeMode personalizado al ThemeMode de Flutter
material.ThemeMode _convertToFlutterThemeMode(app_theme.ThemeMode themeMode) {
  switch (themeMode) {
    case app_theme.ThemeMode.system:
      return material.ThemeMode.system;
    case app_theme.ThemeMode.light:
      return material.ThemeMode.light;
    case app_theme.ThemeMode.dark:
      return material.ThemeMode.dark;
  }
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  static bool _splashRemoved = false;

  @override
  material.Widget build(material.BuildContext context, WidgetRef ref) {
    LoggerFactory.info('🏁 MainApp: build() method called - START');

    // Watch locale state first to get current locale
    final localeState = ref.watch(localeNotifierProvider);
    final currentLocale = localeState.locale?.languageCode ?? 'es';

    // Initialize locale provider if needed
    if (!localeState.isLoading && localeState.locale == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(localeNotifierProvider.notifier).initialize();
      });
    }

    // Initialize date formatting for the current locale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        initializeDateFormatting(currentLocale, null);
      } catch (e) {
        if (kDebugMode) {
          LoggerFactory.info(
              'Date formatting already initialized or error: $e');
        }
      }
    });

    // ✅ SIMPLIFIED STARTUP: Evitar inicialización de providers complejos en build
    LoggerFactory.info(
        '🔄 MainApp: Configuración simplificada para evitar loops');

    // ✅ NO INICIALIZAR PROVIDERS COMPLEJOS EN BUILD - Solo cuando se necesiten
    // Los providers se activarán automáticamente por navegación/interacción del usuario

    if (kDebugMode) {
      LoggerFactory.info(
          '✅ MainApp: Startup simplificado - providers se cargarán bajo demanda');
    }

    // ✅ Remover el splash screen INMEDIATAMENTE en todas las plataformas
    if (!_splashRemoved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_splashRemoved) {
          return;
        }

        try {
          LoggerFactory.info('🎬 Removing splash screen immediately');
          FlutterNativeSplash.remove();
          _splashRemoved = true;
          LoggerFactory.info('✅ Splash screen removed - app UI visible');
        } catch (e) {
          LoggerFactory.error('❌ Error removing splash screen: $e');

          Future.delayed(const Duration(milliseconds: 50), () {
            if (_splashRemoved) {
              return;
            }
            try {
              LoggerFactory.info('🔁 Retrying splash removal attempt');
              FlutterNativeSplash.remove();
              _splashRemoved = true;
              LoggerFactory.info(
                  '✅ Splash screen removed after retry - app UI visible');
            } catch (e2) {
              LoggerFactory.error('❌ Second attempt failed: $e2');
            }
          });
        }

        if (kIsWeb) {
          LoggerFactory.info(
              '🌐 Web platform - splash screen removed for web as well');
        }
      });
    }

    final app_theme.AppTheme appTheme = ref.watch(themeNotifierProvider.select(
      (theme) => app_theme.AppTheme(
        selectedColor: theme.selectedColor,
        themeMode: theme.themeMode,
      ),
    ));

    // ✅ USAR ROUTER SIMPLE PARA DEBUGGEAR
    LoggerFactory.info('✅ Usando configuración simplificada para debug web');

    // Initialize deep link handler for web only once
    // TEMPORARILY DISABLED for web debugging
    // if (kIsWeb && !DeepLinkHandler.isInitialized) {
    //   DeepLinkHandler.initialize(router);
    // }

    // Usar MaterialApp.router para todas las plataformas (incluida web)
    final router = ref.read(appRouterProvider);
    LoggerFactory.info('✅ Router cargado exitosamente');

    return AppStateRestoration(
      child: NavigationErrorBoundary(
        child: material.ScrollConfiguration(
          behavior: CustomScrollBehavior(),
          child: material.MaterialApp.router(
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            theme: appTheme.getTheme(context),
            darkTheme: app_theme.AppTheme(
              selectedColor: appTheme.selectedColor,
              themeMode: app_theme.ThemeMode.dark,
            ).getTheme(context),
            themeMode: _convertToFlutterThemeMode(appTheme.themeMode),
            locale: localeState.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) {
              // Actualizar la UI del sistema cuando cambie el tema
              appTheme.updateSystemUIOverlay(context);
              return child ?? const material.SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

// Función para manejar mensajes de Firebase en segundo plano
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Inicializar Firebase si no está inicializado
  await Firebase.initializeApp();

  if (kDebugMode) {
    LoggerFactory.info('Handling a background message: ${message.messageId}');
  }

  // Aquí se puede procesar el mensaje en segundo plano
  // Por ejemplo, actualizar datos locales, mostrar notificación local, etc.
}
