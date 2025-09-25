import 'dart:io';

/// Script simple para verificar la configuración del archivo .env
void main() {
  print('🔍 Verificando archivo .env...\n');

  final envFile = File('.env');

  if (!envFile.existsSync()) {
    print('❌ Archivo .env no encontrado');
    print('📁 Buscando archivo en: ${envFile.absolute.path}');
    exit(1);
  }

  print('✅ Archivo .env encontrado');

  final content = envFile.readAsStringSync();
  final lines = content.split('\n');

  print('\n📋 Configuraciones encontradas:');

  for (final line in lines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;

    final parts = line.split('=');
    if (parts.length >= 2) {
      final key = parts[0].trim();
      final value = parts.sublist(1).join('=').trim();

      if (value.isNotEmpty) {
        print('✅ $key: ${maskValue(value)}');
      } else {
        print('⚠️ $key: VACÍO');
      }
    }
  }

  print('\n🎯 Verificaciones específicas:');

  // Verificar configuraciones críticas
  final criticalConfigs = {
    'ADSENSE_CLIENT_ID': 'ca-pub-',
    'ADMOB_APP_ID': 'ca-app-pub-',
    'SUPABASE_URL': 'https://',
    'SUPABASE_ANON_KEY': 'eyJ',
  };

  for (final entry in criticalConfigs.entries) {
    checkConfig(lines, entry.key, entry.value);
  }

  print('\n✅ Verificación completada');
}

void checkConfig(List<String> lines, String key, String expectedPrefix) {
  for (final line in lines) {
    if (line.startsWith('$key=')) {
      final value = line.substring(key.length + 1).trim();

      if (value.isEmpty) {
        print('❌ $key: NO CONFIGURADO');
        return;
      }

      if (!value.startsWith(expectedPrefix)) {
        print('⚠️ $key: FORMATO INCORRECTO (esperado: $expectedPrefix...)');
        return;
      }

      print('✅ $key: Correctamente configurado');
      return;
    }
  }

  print('❌ $key: NO ENCONTRADO');
}

String maskValue(String value) {
  if (value.length <= 8) {
    return '${value.substring(0, 4)}****';
  }
  return '${value.substring(0, 8)}${'*' * (value.length - 12)}${value.substring(value.length - 4)}';
}
