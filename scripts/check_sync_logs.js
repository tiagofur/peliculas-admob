/**
 * Script para verificar logs de sincronización en tiempo real
 * Se ejecuta en la consola del navegador para capturar logs de Flutter
 */

// Función para capturar logs de sincronización
function captureSyncLogs() {
  console.log('🔍 Iniciando captura de logs de sincronización...');
  console.log('📝 Logs capturados aparecerán abajo:');
  console.log('=' .repeat(60));
  
  // Interceptar console.log para capturar logs de Flutter
  const originalLog = console.log;
  const originalError = console.error;
  const originalWarn = console.warn;
  
  const syncLogs = [];
  
  // Función para procesar logs
  function processLog(level, args) {
    const message = args.join(' ');
    
    // Filtrar logs relacionados con sincronización
    if (message.includes('SyncLogger') || 
        message.includes('AuthSyncListener') ||
        message.includes('HybridRepository') ||
        message.includes('syncWith') ||
        message.includes('SYNC') ||
        message.includes('🔄') ||
        message.includes('⚠️') ||
        message.includes('❌') ||
        message.includes('✅')) {
      
      const logEntry = {
        timestamp: new Date().toISOString(),
        level: level,
        message: message
      };
      
      syncLogs.push(logEntry);
      
      // Mostrar log con formato
      const timestamp = new Date().toLocaleTimeString();
      console.log(`[${timestamp}] [${level.toUpperCase()}] ${message}`);
      
      // Analizar el tipo de log
      if (message.includes('❌') || level === 'error') {
        console.log('🚨 ERROR DETECTADO - Revisar inmediatamente');
      } else if (message.includes('⚠️') || level === 'warn') {
        console.log('⚠️  ADVERTENCIA - Posible problema');
      } else if (message.includes('✅')) {
        console.log('✅ OPERACIÓN EXITOSA');
      }
    }
  }
  
  // Interceptar métodos de console
  console.log = function(...args) {
    processLog('info', args);
    originalLog.apply(console, args);
  };
  
  console.error = function(...args) {
    processLog('error', args);
    originalError.apply(console, args);
  };
  
  console.warn = function(...args) {
    processLog('warn', args);
    originalWarn.apply(console, args);
  };
  
  // Función para mostrar estadísticas
  window.showSyncStats = function() {
    console.log('\n📊 ESTADÍSTICAS DE LOGS DE SINCRONIZACIÓN:');
    console.log('=' .repeat(50));
    console.log(`Total de logs capturados: ${syncLogs.length}`);
    
    const levels = {};
    syncLogs.forEach(log => {
      levels[log.level] = (levels[log.level] || 0) + 1;
    });
    
    console.log('Por nivel:');
    Object.entries(levels).forEach(([level, count]) => {
      console.log(`  ${level}: ${count}`);
    });
    
    const errors = syncLogs.filter(log => 
      log.message.includes('❌') || log.level === 'error'
    );
    
    if (errors.length > 0) {
      console.log('\n🚨 ERRORES ENCONTRADOS:');
      errors.forEach((error, index) => {
        console.log(`${index + 1}. [${error.timestamp}] ${error.message}`);
      });
    }
    
    const warnings = syncLogs.filter(log => 
      log.message.includes('⚠️') || log.level === 'warn'
    );
    
    if (warnings.length > 0) {
      console.log('\n⚠️  ADVERTENCIAS ENCONTRADAS:');
      warnings.forEach((warning, index) => {
        console.log(`${index + 1}. [${warning.timestamp}] ${warning.message}`);
      });
    }
    
    return syncLogs;
  };
  
  // Función para filtrar logs por tipo
  window.filterSyncLogs = function(filter) {
    const filtered = syncLogs.filter(log => 
      log.message.toLowerCase().includes(filter.toLowerCase())
    );
    
    console.log(`\n🔍 LOGS FILTRADOS POR '${filter}':`);
    console.log('=' .repeat(40));
    filtered.forEach(log => {
      console.log(`[${log.timestamp}] [${log.level}] ${log.message}`);
    });
    
    return filtered;
  };
  
  // Función para limpiar logs
  window.clearSyncLogs = function() {
    syncLogs.length = 0;
    console.log('🧹 Logs de sincronización limpiados');
  };
  
  // Función para exportar logs
  window.exportSyncLogs = function() {
    const dataStr = JSON.stringify(syncLogs, null, 2);
    const dataBlob = new Blob([dataStr], {type: 'application/json'});
    const url = URL.createObjectURL(dataBlob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `sync_logs_${new Date().toISOString().split('T')[0]}.json`;
    link.click();
    console.log('📁 Logs exportados como archivo JSON');
  };
  
  console.log('\n🎯 FUNCIONES DISPONIBLES:');
  console.log('- showSyncStats(): Mostrar estadísticas de logs');
  console.log('- filterSyncLogs("texto"): Filtrar logs por texto');
  console.log('- clearSyncLogs(): Limpiar logs capturados');
  console.log('- exportSyncLogs(): Exportar logs como JSON');
  console.log('\n🔄 Ahora realiza acciones en la app para ver los logs...');
}

// Función para probar sincronización específica
function testSpecificSync() {
  console.log('\n🧪 PRUEBAS ESPECÍFICAS DE SINCRONIZACIÓN:');
  console.log('=' .repeat(50));
  console.log('\n1. 📱 PRUEBA DE LOGIN:');
  console.log('   - Haz logout en la app');
  console.log('   - Haz login nuevamente');
  console.log('   - Observa logs de AuthSyncListener');
  
  console.log('\n2. ❤️  PRUEBA DE FAVORITOS:');
  console.log('   - Agrega una película a favoritos');
  console.log('   - Observa logs de HybridFavoritesRepository');
  console.log('   - Verifica sincronización con Supabase');
  
  console.log('\n3. 📋 PRUEBA DE WATCHLIST:');
  console.log('   - Agrega una película a watchlist');
  console.log('   - Observa logs de HybridWatchlistRepository');
  
  console.log('\n4. ✅ PRUEBA DE PELÍCULAS VISTAS:');
  console.log('   - Marca una película como vista');
  console.log('   - Observa logs de HybridWatchedRepository');
  
  console.log('\n5. 📝 PRUEBA DE LISTAS PERSONALIZADAS:');
  console.log('   - Crea o modifica una lista personalizada');
  console.log('   - Observa logs de HybridCustomListsRepository');
  
  console.log('\n🔍 QUÉ BUSCAR EN LOS LOGS:');
  console.log('✅ Mensajes de sincronización exitosa');
  console.log('🔄 Operaciones de upload/download');
  console.log('⚠️  Advertencias de conflictos o problemas');
  console.log('❌ Errores de conexión o permisos');
  console.log('📊 Estadísticas de rendimiento');
}

// Función para diagnosticar problemas comunes
function diagnoseSyncProblems() {
  console.log('\n🩺 DIAGNÓSTICO DE PROBLEMAS COMUNES:');
  console.log('=' .repeat(50));
  
  console.log('\n🔍 PROBLEMA: "No veo mis favoritos"');
  console.log('   Buscar en logs:');
  console.log('   - "HybridFavoritesRepository"');
  console.log('   - "download" o "upload"');
  console.log('   - Errores de permisos RLS');
  
  console.log('\n🔍 PROBLEMA: "Los cambios no se sincronizan"');
  console.log('   Buscar en logs:');
  console.log('   - "AuthSyncListener"');
  console.log('   - "syncWithSupabase"');
  console.log('   - "connectivity" o "offline"');
  
  console.log('\n🔍 PROBLEMA: "Datos duplicados"');
  console.log('   Buscar en logs:');
  console.log('   - "conflict"');
  console.log('   - "resolution"');
  console.log('   - "merge"');
  
  console.log('\n🔍 PROBLEMA: "App lenta al sincronizar"');
  console.log('   Buscar en logs:');
  console.log('   - Duraciones altas (>3000ms)');
  console.log('   - "retry"');
  console.log('   - "timeout"');
}

// Auto-iniciar captura
captureSyncLogs();
testSpecificSync();
diagnoseSyncProblems();

console.log('\n🎉 Sistema de captura de logs iniciado!');
console.log('💡 Copia y pega este script en la consola del navegador en http://localhost:3000');