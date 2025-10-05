import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/api_keys.dart';
import '../../infrastructure/services/resilient_auth_local_storage.dart';

class SupabaseConfig {
  static String get supabaseUrl => ApiKeys.supabaseUrl;
  static String get supabaseAnonKey => ApiKeys.supabaseAnonKey;

  static Future<void> initialize() async {
    final localStorage = createResilientAuthLocalStorage(supabaseUrl);

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true, // Activar debug para diagnosticar problemas de cache
      // ✅ CRÍTICO: Configurar authOptions para persistir sesión
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce, // Más seguro con PKCE
        localStorage: localStorage,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10,
        logLevel: RealtimeLogLevel.info,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;
  static RealtimeClient get realtime => client.realtime;
}
