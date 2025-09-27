import 'dart:io';

/// Script simple para verificar la configuración del archivo .env
void main() {
  stdout.writeln('🔍 Verificando archivo .env...\n');

  final envFile = File('.env');

  if (!envFile.existsSync()) {
    stdout.writeln('❌ Archivo .env no encontrado');
    stdout.writeln('📁 Buscando archivo en: ${envFile.absolute.path}');
    exit(1);
  }

  stdout.writeln('✅ Archivo .env encontrado');

  final content = envFile.readAsStringSync();
  final lines = content.split('\n');

  stdout.writeln('\n📋 Configuraciones encontradas:');

  for (final line in lines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;

    final parts = line.split('=');
    if (parts.length >= 2) {
      final key = parts[0].trim();
      final value = parts.sublist(1).join('=').trim();

      if (value.isNotEmpty) {
        stdout.writeln('✅ $key: ${maskValue(value)}');
      } else {
        stdout.writeln('⚠️ $key: VACÍO');
      }
    }
  }

  stdout.writeln('\n🎯 Verificaciones específicas:');

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

  stdout.writeln('\n✅ Verificación completada');
}

void checkConfig(List<String> lines, String key, String expectedPrefix) {
  for (final line in lines) {
    if (line.startsWith('$key=')) {
      final value = line.substring(key.length + 1).trim();

      if (value.isEmpty) {
        stdout.writeln('❌ $key: NO CONFIGURADO');
        return;
      }

      if (!value.startsWith(expectedPrefix)) {
        stdout.writeln(
            '⚠️ $key: FORMATO INCORRECTO (esperado: $expectedPrefix...)');
        return;
      }

      stdout.writeln('✅ $key: Correctamente configurado');
      return;
    }
  }

  stdout.writeln('❌ $key: NO ENCONTRADO');
}

String maskValue(String value) {
  if (value.length <= 8) {
    return '${value.substring(0, 4)}****';
  }
  return '${value.substring(0, 8)}${'*' * (value.length - 12)}${value.substring(value.length - 4)}';
}
