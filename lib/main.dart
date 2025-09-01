import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_in_app_pip/flutter_in_app_pip.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/constants/environment.dart';
import 'config/deep_links/deep_link_handler.dart';
import 'config/router/app_router.dart';
import 'config/theme/app_theme.dart';
import 'config/theme/custom_scroll_behavior.dart';
import 'core/config/supabase_config.dart';
import 'core/error_reporting/error_reporting_service.dart';
import 'core/logging/logger_factory.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/notification_initialization_service.dart';
import 'generated/app_localizations.dart';
import 'infrastructure/services/app_lifecycle_manager.dart';
import 'infrastructure/services/auth_session_manager.dart';
import 'infrastructure/services/connectivity_detector.dart';
import 'infrastructure/services/cross_platform_init_service.dart';
import 'infrastructure/services/token_refresh_service.dart';
import 'presentation/providers/challenge_providers.dart';
import 'presentation/providers/error_reporting_provider.dart';
import 'presentation/providers/locale/locale_provider.dart';
import 'presentation/providers/multiplatform_sync_provider.dart';
import 'presentation/providers/sync_init_provider.dart';
import 'presentation/providers/sync_integration_provider.dart';
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
            LoggerFactory.info('✅ Sistema de autenticación persistente inicializado');
          }
        } catch (e) {
          if (kDebugMode) {
            LoggerFactory.error('❌ Error inicializando autenticación persistente: $e');
          }
        }

        // INICIALIZAR SISTEMA DE SINCRONIZACIÓN MULTIPLATAFORMA
        try {
          // Inicializar detector de conectividad
          await ConnectivityDetector.instance.initialize();

          // Inicializar gestor del ciclo de vida
          AppLifecycleManager.instance.initialize();

          if (kDebugMode) {
            LoggerFactory
                .info('✅ Sistema de sincronización multiplataforma inicializado');
          }
        } catch (e) {
          if (kDebugMode) {
            LoggerFactory
                .error('❌ Error inicializando sistema de sincronización: $e');
          }
        }

        // INICIALIZAR SISTEMA DE CACHÉ DE IMÁGENES
        await HybridImageService.instance.initialize();

        // Configurar servicio de precarga de imágenes
        ImagePreloaderService().configure(
          enabled: true,
          maxConcurrentPreloads: 3,
        );

        // INICIALIZAR SERVICIO DE CONFIGURACIÓN DE CACHÉ
        await CacheConfigurationService().initialize();

        // Note: Offline cache manager will be initialized when first accessed through providers
        if (kDebugMode) {
          LoggerFactory.info('✅ Cache services configured - offline cache will initialize on demand');
        }

        // INICIALIZAR SISTEMA DE NOTIFICACIONES
        if (!kIsWeb) {
          try {
            await NotificationInitializationService.instance.initialize();
            
            // Configurar navigator key para navegación desde notificaciones
            NotificationInitializationService.instance.setNavigatorKey(globalNavigatorKey);
            LocalNotificationService.instance.setNavigatorKey(globalNavigatorKey);
            
            if (kDebugMode) {
              LoggerFactory.info('✅ Sistema de notificaciones inicializado con navegación');
            }
          } catch (e) {
            if (kDebugMode) {
              LoggerFactory
                  .error('❌ Error inicializando sistema de notificaciones: $e');
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

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    initializeDateFormatting();

    // INICIALIZAR SYNC LISTENER - Esto es CRÍTICO para que funcione la sincronización automática
    ref.watch(authSyncListenerProvider);

    // INICIALIZAR SISTEMA DE SINCRONIZACIÓN MULTIPLATAFORMA
    ref.watch(syncInitializationProvider);

    // INICIALIZAR INTEGRACIÓN DE SYNC UI
    ref.watch(syncIntegrationInitProvider);

    // INICIALIZAR CHALLENGE SYSTEM
    ref.watch(challengeInitializationProvider);

    // INICIALIZAR ERROR REPORTING USER CONTEXT
    ref.watch(errorReportingUserContextProvider);

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

    final AppTheme appTheme = ref.watch(themeNotifierProvider.select(
      (theme) => AppTheme(
        selectedColor: theme.selectedColor,
        themeMode: theme.themeMode,
      ),
    ));

    // Watch locale state
    final localeState = ref.watch(localeNotifierProvider);

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
      return ScrollConfiguration(
        behavior: CustomScrollBehavior(),
        child: MaterialApp.router(
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          theme: appTheme.getTheme(),
          locale: localeState.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            // Actualizar la UI del sistema cuando cambie el tema
            appTheme.updateSystemUIOverlay(context);
            return child ?? const SizedBox.shrink();
          },
        ),
      );
    }

    return PiPMaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: appTheme.getTheme(),
      locale: localeState.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        // Actualizar la UI del sistema cuando cambie el tema
        appTheme.updateSystemUIOverlay(context);
        return child ?? const SizedBox.shrink();
      },
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

// Función para manejar mensajes de Firebase en segundo plano
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Inicializar Firebase si no está inicializado
  await Firebase.initializeApp();

  if (kDebugMode) {
    LoggerFactory
        .info('Handling a background message: ${message.messageId}');
  }

  // Aquí se puede procesar el mensaje en segundo plano
  // Por ejemplo, actualizar datos locales, mostrar notificación local, etc.
}
