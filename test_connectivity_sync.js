/**
 * Script de diagnóstico para verificar detección de conectividad y sincronización
 * Ejecutar en la consola del navegador mientras la app Flutter está corriendo
 */

// Configuración del test
const CONNECTIVITY_TEST_CONFIG = {
  testDuration: 30000, // 30 segundos
  checkInterval: 2000, // Verificar cada 2 segundos
  simulateOfflineTime: 10000, // Simular offline por 10 segundos
  testUrls: [
    'https://httpbin.org/get',
    'https://jsonplaceholder.typicode.com/posts/1',
    'https://api.github.com'
  ]
};

// Utilidades para simular conectividad
const ConnectivitySimulator = {
  originalFetch: window.fetch,
  isSimulatingOffline: false,
  blockedRequests: [],
  
  // Simular estado offline
  simulateOffline() {
    console.log('🔴 Simulando estado OFFLINE...');
    this.isSimulatingOffline = true;
    
    // Interceptar fetch para simular falta de conexión
    window.fetch = async (...args) => {
      const [url] = args;
      this.blockedRequests.push({
        url: url.toString(),
        timestamp: new Date().toISOString(),
        blocked: true
      });
      
      console.log('❌ Request bloqueado (simulando offline):', url.toString());
      throw new Error('Network request failed - simulating offline');
    };
    
    // Simular evento de conectividad offline
    if (navigator.onLine !== undefined) {
      Object.defineProperty(navigator, 'onLine', {
        writable: true,
        value: false
      });
      
      // Disparar evento offline
      window.dispatchEvent(new Event('offline'));
    }
  },
  
  // Restaurar estado online
  restoreOnline() {
    console.log('🟢 Restaurando estado ONLINE...');
    this.isSimulatingOffline = false;
    
    // Restaurar fetch original
    window.fetch = this.originalFetch;
    
    // Restaurar navigator.onLine
    if (navigator.onLine !== undefined) {
      Object.defineProperty(navigator, 'onLine', {
        writable: true,
        value: true
      });
      
      // Disparar evento online
      window.dispatchEvent(new Event('online'));
    }
  },
  
  // Obtener estadísticas de requests bloqueados
  getBlockedRequestsStats() {
    return {
      totalBlocked: this.blockedRequests.length,
      uniqueUrls: [...new Set(this.blockedRequests.map(req => req.url))],
      requests: this.blockedRequests
    };
  },
  
  // Limpiar estadísticas
  clearStats() {
    this.blockedRequests = [];
  }
};

// Monitor de estado de conectividad
const ConnectivityMonitor = {
  states: [],
  isMonitoring: false,
  monitorInterval: null,
  
  // Iniciar monitoreo
  startMonitoring() {
    if (this.isMonitoring) return;
    
    console.log('🔄 Iniciando monitoreo de conectividad...');
    this.isMonitoring = true;
    this.states = [];
    
    this.monitorInterval = setInterval(() => {
      this.captureState();
    }, CONNECTIVITY_TEST_CONFIG.checkInterval);
  },
  
  // Detener monitoreo
  stopMonitoring() {
    if (!this.isMonitoring) return;
    
    console.log('⏹️ Deteniendo monitoreo de conectividad...');
    this.isMonitoring = false;
    
    if (this.monitorInterval) {
      clearInterval(this.monitorInterval);
      this.monitorInterval = null;
    }
  },
  
  // Capturar estado actual
  captureState() {
    const state = {
      timestamp: new Date().toISOString(),
      navigatorOnline: navigator.onLine,
      simulatingOffline: ConnectivitySimulator.isSimulatingOffline,
      // Intentar detectar elementos de UI relacionados con conectividad
      uiIndicators: this.checkUIConnectivityIndicators(),
      // Verificar si hay elementos de loading/error
      loadingStates: this.checkLoadingStates(),
      // Verificar contadores de listas
      listCounts: this.checkListCounts()
    };
    
    this.states.push(state);
    
    // Log solo si hay cambios significativos
    const previousState = this.states[this.states.length - 2];
    if (!previousState || this.hasSignificantChanges(previousState, state)) {
      console.log('📊 Estado de conectividad capturado:', state);
    }
  },
  
  // Verificar indicadores de conectividad en la UI
  checkUIConnectivityIndicators() {
    return {
      offlineIndicators: document.querySelectorAll('.offline, [data-testid*="offline"], .no-connection').length,
      onlineIndicators: document.querySelectorAll('.online, [data-testid*="online"], .connected').length,
      syncIndicators: document.querySelectorAll('.syncing, [data-testid*="sync"], .sync-status').length,
      errorBanners: document.querySelectorAll('.error-banner, .connection-error, .network-error').length
    };
  },
  
  // Verificar estados de carga
  checkLoadingStates() {
    return {
      spinners: document.querySelectorAll('.loading, .spinner, [data-testid*="loading"]').length,
      skeletons: document.querySelectorAll('.skeleton, .shimmer').length,
      progressBars: document.querySelectorAll('.progress, .progress-bar').length
    };
  },
  
  // Verificar contadores de listas
  checkListCounts() {
    return {
      movieCards: document.querySelectorAll('.movie-card, [data-testid*="movie"]').length,
      listItems: document.querySelectorAll('.list-item, li').length,
      emptyStates: document.querySelectorAll('.empty, .no-data, [data-testid*="empty"]').length
    };
  },
  
  // Verificar si hay cambios significativos
  hasSignificantChanges(previous, current) {
    return (
      previous.navigatorOnline !== current.navigatorOnline ||
      previous.simulatingOffline !== current.simulatingOffline ||
      JSON.stringify(previous.uiIndicators) !== JSON.stringify(current.uiIndicators) ||
      JSON.stringify(previous.listCounts) !== JSON.stringify(current.listCounts)
    );
  },
  
  // Obtener resumen de estados
  getStatesSummary() {
    if (this.states.length === 0) return null;
    
    const summary = {
      totalStates: this.states.length,
      duration: this.states.length > 1 
        ? new Date(this.states[this.states.length - 1].timestamp).getTime() - new Date(this.states[0].timestamp).getTime()
        : 0,
      connectivityChanges: 0,
      uiChanges: 0,
      listCountChanges: 0
    };
    
    for (let i = 1; i < this.states.length; i++) {
      const prev = this.states[i - 1];
      const curr = this.states[i];
      
      if (prev.navigatorOnline !== curr.navigatorOnline || prev.simulatingOffline !== curr.simulatingOffline) {
        summary.connectivityChanges++;
      }
      
      if (JSON.stringify(prev.uiIndicators) !== JSON.stringify(curr.uiIndicators)) {
        summary.uiChanges++;
      }
      
      if (JSON.stringify(prev.listCounts) !== JSON.stringify(curr.listCounts)) {
        summary.listCountChanges++;
      }
    }
    
    return summary;
  }
};

// Función principal de diagnóstico
async function diagnoseConnectivitySync() {
  console.log('🔍 INICIANDO DIAGNÓSTICO DE CONECTIVIDAD Y SINCRONIZACIÓN');
  console.log('=' .repeat(70));
  
  const results = {
    initialState: null,
    offlineSimulation: null,
    onlineRestoration: null,
    networkRequests: null,
    issues: []
  };
  
  try {
    // 1. Capturar estado inicial
    console.log('\n📊 1. Capturando estado inicial...');
    ConnectivityMonitor.startMonitoring();
    
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    results.initialState = {
      navigatorOnline: navigator.onLine,
      uiState: ConnectivityMonitor.checkUIConnectivityIndicators(),
      listCounts: ConnectivityMonitor.checkListCounts()
    };
    
    console.log('Estado inicial:', results.initialState);
    
    // 2. Simular pérdida de conectividad
    console.log('\n🔴 2. Simulando pérdida de conectividad...');
    ConnectivitySimulator.simulateOffline();
    
    // Esperar a que la app reaccione
    await new Promise(resolve => setTimeout(resolve, CONNECTIVITY_TEST_CONFIG.simulateOfflineTime));
    
    results.offlineSimulation = {
      navigatorOnline: navigator.onLine,
      uiState: ConnectivityMonitor.checkUIConnectivityIndicators(),
      listCounts: ConnectivityMonitor.checkListCounts(),
      blockedRequests: ConnectivitySimulator.getBlockedRequestsStats()
    };
    
    console.log('Estado durante simulación offline:', results.offlineSimulation);
    
    // Verificar si la UI reaccionó al estado offline
    if (results.offlineSimulation.uiState.offlineIndicators === 0) {
      results.issues.push('❌ La UI no mostró indicadores de estado offline');
    }
    
    if (results.offlineSimulation.blockedRequests.totalBlocked === 0) {
      results.issues.push('⚠️ No se detectaron requests bloqueados durante simulación offline');
    }
    
    // 3. Restaurar conectividad
    console.log('\n🟢 3. Restaurando conectividad...');
    ConnectivitySimulator.restoreOnline();
    
    // Esperar a que la app se recupere
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    results.onlineRestoration = {
      navigatorOnline: navigator.onLine,
      uiState: ConnectivityMonitor.checkUIConnectivityIndicators(),
      listCounts: ConnectivityMonitor.checkListCounts()
    };
    
    console.log('Estado después de restaurar conectividad:', results.onlineRestoration);
    
    // Verificar si la UI se recuperó
    if (results.onlineRestoration.uiState.offlineIndicators > 0) {
      results.issues.push('❌ La UI sigue mostrando indicadores offline después de restaurar conexión');
    }
    
    // 4. Probar conectividad real
    console.log('\n🌐 4. Probando conectividad real...');
    const connectivityTests = [];
    
    for (const testUrl of CONNECTIVITY_TEST_CONFIG.testUrls) {
      try {
        const startTime = Date.now();
        const response = await fetch(testUrl, {
          method: 'GET',
          headers: { 'Cache-Control': 'no-cache' },
          signal: AbortSignal.timeout(5000)
        });
        const endTime = Date.now();
        
        connectivityTests.push({
          url: testUrl,
          success: response.ok,
          status: response.status,
          duration: endTime - startTime
        });
        
        console.log(`✅ Test de conectividad exitoso: ${testUrl} (${response.status})`);
      } catch (error) {
        connectivityTests.push({
          url: testUrl,
          success: false,
          error: error.message,
          duration: null
        });
        
        console.log(`❌ Test de conectividad falló: ${testUrl} - ${error.message}`);
      }
    }
    
    results.networkRequests = {
      tests: connectivityTests,
      successRate: connectivityTests.filter(test => test.success).length / connectivityTests.length,
      averageResponseTime: connectivityTests
        .filter(test => test.success && test.duration)
        .reduce((sum, test) => sum + test.duration, 0) / connectivityTests.filter(test => test.success).length || 0
    };
    
    if (results.networkRequests.successRate < 0.5) {
      results.issues.push('❌ Más del 50% de las pruebas de conectividad fallaron');
    }
    
    // 5. Detener monitoreo y analizar
    ConnectivityMonitor.stopMonitoring();
    const statesSummary = ConnectivityMonitor.getStatesSummary();
    
    console.log('\n📈 5. Análisis de cambios de estado:');
    console.log('Resumen de estados:', statesSummary);
    
    if (statesSummary && statesSummary.connectivityChanges === 0) {
      results.issues.push('❌ No se detectaron cambios de conectividad durante la prueba');
    }
    
    if (statesSummary && statesSummary.uiChanges === 0) {
      results.issues.push('❌ No se detectaron cambios en la UI durante la prueba');
    }
    
  } catch (error) {
    console.error('❌ Error durante el diagnóstico:', error);
    results.issues.push(`❌ Error: ${error.message}`);
  } finally {
    // Asegurar que se restaure el estado
    ConnectivitySimulator.restoreOnline();
    ConnectivityMonitor.stopMonitoring();
  }
  
  // 6. Generar reporte final
  console.log('\n📋 REPORTE DE DIAGNÓSTICO DE CONECTIVIDAD');
  console.log('=' .repeat(70));
  
  if (results.issues.length === 0) {
    console.log('✅ ¡El sistema de conectividad y sincronización funciona correctamente!');
  } else {
    console.log('❌ Se encontraron problemas:');
    results.issues.forEach(issue => console.log(`  ${issue}`));
  }
  
  console.log('\n📊 Resumen:');
  console.log(`  - Estado inicial online: ${results.initialState?.navigatorOnline}`);
  console.log(`  - Requests bloqueados durante offline: ${results.offlineSimulation?.blockedRequests?.totalBlocked || 0}`);
  console.log(`  - Tasa de éxito de conectividad: ${((results.networkRequests?.successRate || 0) * 100).toFixed(1)}%`);
  console.log(`  - Tiempo promedio de respuesta: ${(results.networkRequests?.averageResponseTime || 0).toFixed(0)}ms`);
  
  return results;
}

// Función para monitoreo continuo
function startConnectivityMonitoring() {
  console.log('🔄 Iniciando monitoreo continuo de conectividad...');
  
  ConnectivityMonitor.startMonitoring();
  
  // Escuchar eventos de conectividad del navegador
  window.addEventListener('online', () => {
    console.log('🟢 Evento ONLINE detectado');
  });
  
  window.addEventListener('offline', () => {
    console.log('🔴 Evento OFFLINE detectado');
  });
  
  console.log('✅ Monitoreo continuo iniciado. Para detener, ejecuta: ConnectivityTester.stopMonitoring()');
}

// Exportar funciones
window.ConnectivityTester = {
  diagnose: diagnoseConnectivitySync,
  startMonitoring: startConnectivityMonitoring,
  stopMonitoring: () => ConnectivityMonitor.stopMonitoring(),
  simulator: ConnectivitySimulator,
  monitor: ConnectivityMonitor
};

console.log('🚀 Script de diagnóstico de conectividad cargado.');
console.log('📋 Comandos disponibles:');
console.log('  - ConnectivityTester.diagnose() - Ejecutar diagnóstico completo');
console.log('  - ConnectivityTester.startMonitoring() - Iniciar monitoreo continuo');
console.log('  - ConnectivityTester.stopMonitoring() - Detener monitoreo');
console.log('  - ConnectivityTester.simulator.* - Simular estados de conectividad');
console.log('  - ConnectivityTester.monitor.* - Acceder al monitor de estados');

// Auto-ejecutar si se desea
// diagnoseConnectivitySync();