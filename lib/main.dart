import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
// Importar flutter_in_app_pip solo en plataformas nativas
import 'package:flutter_in_app_pip/flutter_in_app_pip.dart'
    if (dart.library.html) 'core/platform/pip_stub.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/constants/environment.dart';
import 'config/deep_links/deep_link_handler.dart';
import 'config/router/app_router.dart';
import 'config/theme/app_theme.dart' as app_theme;
import 'config/theme/custom_scroll_behavior.dart';
import 'core/cache/image_cache_manager.dart';
import 'core/config/supabase_config.dart';
import 'core/error_reporting/error_reporting_service.dart';
import 'core/logging/logger_factory.dart';
import 'core/monetization/monetization_initializer.dart';
import 'core/navigation/enhanced_notification_service.dart';
import 'core/navigation/navigation_error_boundary.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/notification_initialization_service.dart';
import 'core/state/app_state_manager.dart';
import 'core/state/app_state_restoration.dart';
import 'core/utils/server_timestamp_utils.dart';
import 'generated/app_localizations.dart';
import 'infrastructure/services/app_lifecycle_manager.dart';
import 'infrastructure/services/auth_session_manager.dart';
import 'infrastructure/services/connectivity_detector.dart';
import 'infrastructure/services/cross_platform_init_service.dart';
import 'infrastructure/services/token_refresh_service.dart';
import 'presentation/providers/auto_default_lists_provider.dart';
import 'presentation/providers/error_reporting_provider.dart';
import 'presentation/providers/locale/locale_provider.dart';
import 'presentation/providers/post_login_initialization_provider.dart';
import 'presentation/providers/storage/direct_providers_helpers.dart';
import 'presentation/providers/theme/theme_provider.dart';
import 'services/cache_configuration_service.dart';
import 'services/hybrid_image_service.dart';
import 'services/image_preloader_service.dart';

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

  // Initialize error reporting first to catch initialization errors
  await ErrorReportingService.instance.initialize();

  // Wrap the entire initialization in error reporting zone
  await ErrorReportingService.instance.runAsyncWithErrorReporting(
    () async {
      try {
        // Cargar variables de entorno
        await Environment.load();

        // INICIALIZAR SERVICIOS MULTIPLATAFORMA (Hive, Storage, etc.)
        await CrossPlatformInitService.instance.initialize();

        // INICIALIZAR FIREBASE
        if (!kIsWeb) {
          try {
            await Firebase.initializeApp();

            // Configurar el manejo de mensajes en segundo plano
            FirebaseMessaging.onBackgroundMessage(
                _firebaseMessagingBackgroundHandler);

            // Solicitar permisos de notificación
            await FirebaseMessaging.instance.requestPermission(
              alert: true,
              announcement: false,
              badge: true,
              carPlay: false,
              criticalAlert: false,
              provisional: false,
              sound: true,
            );

            if (kDebugMode) {
              LoggerFactory.info('✅ Firebase inicializado correctamente');
            }
          } catch (e) {
            if (kDebugMode) {
              LoggerFactory.error('❌ Error inicializando Firebase: $e');
            }
          }
        }

        // INICIALIZAR SUPABASE
        await SupabaseConfig.initialize();

        // INICIALIZAR GESTORES DE AUTENTICACIÓN PERSISTENTE
        try {
          await AuthSessionManager.instance.initialize();
          await TokenRefreshService.instance.initialize();

          if (kDebugMode) {
            LoggerFactory.info(
                '✅ Sistema de autenticación persistente inicializado');
          }
        } catch (e) {
          if (kDebugMode) {
            LoggerFactory.error(
                '❌ Error inicializando autenticación persistente: $e');
          }
        }

        // INICIALIZAR GESTOR DE ESTADO DE APLICACIÓN
        try {
          await AppStateManager.instance.initialize();
          if (kDebugMode) {
            LoggerFactory.info('✅ AppStateManager inicializado');
          }
        } catch (e) {
          if (kDebugMode) {
            LoggerFactory.error('❌ Error inicializando AppStateManager: $e');
          }
        }

        // INICIALIZAR SISTEMA DE SINCRONIZACIÓN MULTIPLATAFORMA
        try {
          // Inicializar detector de conectividad
          await ConnectivityDetector.instance.initialize();

          // Inicializar gestor del ciclo de vida
          AppLifecycleManager.instance.initialize();

          if (kDebugMode) {
            LoggerFactory.info(
                '✅ Sistema de sincronización multiplataforma inicializado');
          }
        } catch (e) {
          if (kDebugMode) {
            LoggerFactory.error(
                '❌ Error inicializando sistema de sincronización: $e');
          }
        }

        // INICIALIZAR SISTEMA DE CACHÉ DE IMÁGENES
        await HybridImageService.instance.initialize();

        // Configurar servicio de precarga de imágenes
        ImagePreloaderService().configure(
          enabled: true,
          maxConcurrentPreloads: 3,
        );

        // INICIALIZAR SERVICIOS DE CACHÉ
        await CacheConfigurationService().initialize();

        // Inicializar Image Cache Manager con configuración adaptativa
        await ImageCacheManager.instance.initialize();

        // Inicializar cache de server timestamp para sync
        await ServerTimestampUtils.updateServerTimestampCache();

        // Note: Offline cache manager will be initialized when first accessed through providers
        if (kDebugMode) {
          LoggerFactory.info(
              '✅ Cache services configured - offline cache will initialize on demand');
        }

        // INICIALIZAR SISTEMA DE NOTIFICACIONES MEJORADO
        if (!kIsWeb) {
          try {
            // Inicializar servicio mejorado de notificaciones
            await EnhancedNotificationService.instance
                .initialize(globalNavigatorKey);

            // Mantener compatibilidad con servicios existentes
            NotificationInitializationService.instance
                .setNavigatorKey(globalNavigatorKey);
            LocalNotificationService.instance
                .setNavigatorKey(globalNavigatorKey);

            if (kDebugMode) {
              LoggerFactory.info(
                  '✅ Sistema de notificaciones mejorado inicializado con navegación segura');
            }
          } catch (e) {
            if (kDebugMode) {
              LoggerFactory.error(
                  '❌ Error inicializando sistema de notificaciones mejorado: $e');
            }
          }
        }

        // INICIALIZAR ADMOB solo en plataformas móviles
        if (!kIsWeb) {
          try {
            await MobileAds.instance.initialize();
          } catch (e) {
            if (kDebugMode) {
              LoggerFactory.error('Error initializing MobileAds: $e');
            }
          }
        }

        // INICIALIZAR SISTEMA DE MONETIZACIÓN
        try {
          await MonetizationInitializer.instance.initialize(
            enableDebugMode: kDebugMode,
          );
          if (kDebugMode) {
            LoggerFactory.info('✅ Sistema de monetización inicializado');
          }
        } catch (e) {
          if (kDebugMode) {
            LoggerFactory.error(
                '❌ Error inicializando sistema de monetización: $e');
          }
        }

        // Habilitar edge-to-edge para Android 15 (SDK 35)
        if (!kIsWeb) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }

        if (kDebugMode) {
          LoggerFactory.info(
              '✅ Aplicación inicializada correctamente para ${kIsWeb ? 'Web' : 'plataforma nativa'}');
        }
      } catch (e, stackTrace) {
        LoggerFactory.reportCriticalError(
          e,
          stackTrace,
          context: 'Application initialization',
          fatal: false,
        );
        // Continuar con la ejecución aunque haya errores de inicialización
      }
    },
    zoneName: 'ApplicationInitialization',
    customData: {
      'platform': kIsWeb ? 'web' : 'native',
      'isDebugMode': kDebugMode,
    },
  );

  runApp(const ProviderScope(child: MainApp()));
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

  @override
  material.Widget build(material.BuildContext context, WidgetRef ref) {
    LoggerFactory.info('🏁 MainApp: build() method called - START');

    // Watch locale state first to get current locale
    final localeState = ref.watch(localeNotifierProvider);
    final currentLocale = localeState.locale?.languageCode ?? 'es';

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

    // LAZY LOADING DE SERVICES ESENCIALES PARA EVITAR BLOQUEOS EN STARTUP
    LoggerFactory.info(
        '🔄 MainApp: Configurando services esenciales (LAZY)...');

    try {
      // Solo inicializar services esenciales que no bloqueen el startup
      ref.watch(errorReportingUserContextProvider);

      // Observar estado de autenticación para inicialización automática de direct providers
      ref.watch(authStateDirectProvidersProvider);

      // INICIALIZAR SISTEMA AUTOMÁTICO DE LISTAS PREDETERMINADAS
      ref.watch(authDefaultListsListenerProvider);
    } catch (e) {
      if (kDebugMode) {
        LoggerFactory.info('Some services not available on startup: $e');
      }
    }
    LoggerFactory.info('✅ MainApp: Essential services configured (LAZY)');

    // REACTIVAR: INICIALIZACIÓN POST-LOGIN (con modificaciones anti-bloqueo)
    // FIXED: Legacy compatibility restored
    ref.watch(postLoginInitializationProvider); // Reactivado para habilitar enableAfterLogin()

    // Los DirectProviders se inicializarán automáticamente cuando sean necesarios
    // para evitar bloqueos en el startup - inicialización ya manejada arriba
    LoggerFactory.info(
        '✅ MainApp: DirectProviders configurados para lazy loading');

    // INICIALIZACIÓN LAZY DE PROVIDERS - Solo cuando se necesiten
    // Los providers se inicializarán automáticamente cuando se usen por primera vez
    if (kDebugMode) {
      LoggerFactory.info(
          '✅ Usando providers directos (favoritos + vistas) para debugging');
    }

    // SYNC SERVICE será inicializado automáticamente cuando el usuario se autentique
    if (kDebugMode) {
      LoggerFactory.info(
          '✅ Sync service will be initialized on user authentication');
    }

    // Remover el splash screen solo en plataformas móviles
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          FlutterNativeSplash.remove();
        } catch (e) {
          if (kDebugMode) {
            LoggerFactory.error('Error removing splash screen: $e');
          }
        }
      });
    }

    final app_theme.AppTheme appTheme = ref.watch(themeNotifierProvider.select(
      (theme) => app_theme.AppTheme(
        selectedColor: theme.selectedColor,
        themeMode: theme.themeMode,
      ),
    ));

    // Usar el router provider con autenticación
    final router = ref.watch(appRouterProvider);

    // Initialize deep link handler for web
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        DeepLinkHandler.initialize(router);
      });
    }

    // Usar MaterialApp regular para web para evitar problemas de compatibilidad
    if (kIsWeb) {
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

    // Usar PiPMaterialApp solo en plataformas nativas (no web)
    return AppStateRestoration(
      child: NavigationErrorBoundary(
        child: material.ScrollConfiguration(
          behavior: CustomScrollBehavior(),
          child: PiPMaterialApp.router(
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
            pipParams: const PiPParams(
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
