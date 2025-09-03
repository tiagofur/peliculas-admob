/**
 * Script para verificar la reactividad de providers en Flutter con Riverpod
 * Ejecutar en la consola del navegador mientras la app Flutter está corriendo
 */

// Configuración para interceptar llamadas de red
const NetworkInterceptor = {
  originalFetch: window.fetch,
  requests: [],
  
  init() {
    window.fetch = async (...args) => {
      const [url, options] = args;
      const startTime = Date.now();
      
      console.log('🌐 Interceptando request:', {
        url: url.toString(),
        method: options?.method || 'GET',
        timestamp: new Date().toISOString()
      });
      
      try {
        const response = await NetworkInterceptor.originalFetch(...args);
        const endTime = Date.now();
        
        const requestInfo = {
          url: url.toString(),
          method: options?.method || 'GET',
          status: response.status,
          duration: endTime - startTime,
          timestamp: new Date().toISOString(),
          success: response.ok
        };
        
        NetworkInterceptor.requests.push(requestInfo);
        
        console.log('✅ Request completado:', requestInfo);
        
        // Verificar si es una llamada a Supabase
        if (url.toString().includes('supabase')) {
          console.log('🔄 Llamada a Supabase detectada - verificando sincronización');
        }
        
        return response;
      } catch (error) {
        const endTime = Date.now();
        
        const requestInfo = {
          url: url.toString(),
          method: options?.method || 'GET',
          error: error.message,
          duration: endTime - startTime,
          timestamp: new Date().toISOString(),
          success: false
        };
        
        NetworkInterceptor.requests.push(requestInfo);
        
        console.error('❌ Request falló:', requestInfo);
        throw error;
      }
    };
    
    console.log('✅ Interceptor de red inicializado');
  },
  
  getRecentRequests(minutes = 5) {
    const cutoff = Date.now() - (minutes * 60 * 1000);
    return this.requests.filter(req => new Date(req.timestamp).getTime() > cutoff);
  },
  
  getSupabaseRequests() {
    return this.requests.filter(req => req.url.includes('supabase'));
  },
  
  reset() {
    this.requests = [];
    console.log('🔄 Historial de requests limpiado');
  }
};

// Utilidades para verificar el estado de Flutter
const FlutterStateChecker = {
  // Verificar si hay elementos de carga
  checkLoadingStates() {
    const loadingElements = {
      spinners: document.querySelectorAll('.loading, .spinner, [data-testid*="loading"]').length,
      progressBars: document.querySelectorAll('.progress, .progress-bar').length,
      skeletons: document.querySelectorAll('.skeleton, .shimmer').length,
      circularProgress: document.querySelectorAll('flt-semantics[aria-label*="loading"], flt-semantics[aria-label*="cargando"]').length
    };
    
    const totalLoading = Object.values(loadingElements).reduce((sum, count) => sum + count, 0);
    
    return {
      ...loadingElements,
      totalLoading,
      isLoading: totalLoading > 0
    };
  },
  
  // Verificar errores en la UI
  checkErrorStates() {
    const errorElements = {
      errorMessages: document.querySelectorAll('.error, .error-message, [data-testid*="error"]').length,
      alerts: document.querySelectorAll('.alert, .notification').length,
      emptyStates: document.querySelectorAll('.empty, .no-data, [data-testid*="empty"]').length
    };
    
    const totalErrors = Object.values(errorElements).reduce((sum, count) => sum + count, 0);
    
    return {
      ...errorElements,
      totalErrors,
      hasErrors: totalErrors > 0
    };
  },
  
  // Contar elementos de listas
  countListItems() {
    const listCounts = {
      movieCards: document.querySelectorAll('.movie-card, [data-testid*="movie"]').length,
      listItems: document.querySelectorAll('.list-item, li').length,
      gridItems: document.querySelectorAll('.grid-item, .card').length
    };
    
    return listCounts;
  },
  
  // Verificar navegación
  checkNavigation() {
    const navInfo = {
      currentUrl: window.location.href,
      activeTab: document.querySelector('.tab.active, .nav-item.active')?.textContent?.trim() || 'unknown',
      availableTabs: Array.from(document.querySelectorAll('.tab, .nav-item')).map(tab => tab.textContent?.trim()).filter(Boolean)
    };
    
    return navInfo;
  }
};

// Función principal para verificar reactividad de providers
async function testProviderReactivity() {
  console.log('🔍 INICIANDO PRUEBA DE REACTIVIDAD DE PROVIDERS');
  console.log('=' .repeat(60));
  
  const testResults = {
    initialState: null,
    networkActivity: [],
    stateChanges: [],
    issues: []
  };
  
  try {
    // 1. Inicializar interceptor de red
    NetworkInterceptor.init();
    
    // 2. Capturar estado inicial
    console.log('\n📊 1. Capturando estado inicial...');
    testResults.initialState = {
      loading: FlutterStateChecker.checkLoadingStates(),
      errors: FlutterStateChecker.checkErrorStates(),
      lists: FlutterStateChecker.countListItems(),
      navigation: FlutterStateChecker.checkNavigation()
    };
    
    console.log('Estado inicial capturado:', testResults.initialState);
    
    // 3. Simular interacciones y monitorear cambios
    console.log('\n🎯 2. Simulando interacciones...');
    
    const interactions = [
      {
        name: 'Toggle Favorito',
        action: () => {
          const btn = document.querySelector('[data-testid="favorite-button"], .favorite-button, button[title*="favorito"]');
          if (btn) {
            btn.click();
            return true;
          }
          return false;
        }
      },
      {
        name: 'Toggle Watchlist',
        action: () => {
          const btn = document.querySelector('[data-testid="watchlist-button"], .watchlist-button, button[title*="watchlist"]');
          if (btn) {
            btn.click();
            return true;
          }
          return false;
        }
      },
      {
        name: 'Marcar como Vista',
        action: () => {
          const btn = document.querySelector('[data-testid="watched-button"], .watched-button, button[title*="vista"]');
          if (btn) {
            btn.click();
            return true;
          }
          return false;
        }
      }
    ];
    
    for (const interaction of interactions) {
      console.log(`\n🎯 Probando: ${interaction.name}`);
      
      const beforeState = {
        loading: FlutterStateChecker.checkLoadingStates(),
        lists: FlutterStateChecker.countListItems(),
        requestCount: NetworkInterceptor.requests.length
      };
      
      const success = interaction.action();
      
      if (success) {
        console.log(`✅ ${interaction.name} ejecutado`);
        
        // Esperar un momento para que se procesen los cambios
        await new Promise(resolve => setTimeout(resolve, 3000));
        
        const afterState = {
          loading: FlutterStateChecker.checkLoadingStates(),
          lists: FlutterStateChecker.countListItems(),
          requestCount: NetworkInterceptor.requests.length
        };
        
        // Analizar cambios
        const stateChange = {
          interaction: interaction.name,
          beforeState,
          afterState,
          networkRequestsMade: afterState.requestCount - beforeState.requestCount,
          loadingStateChanged: beforeState.loading.isLoading !== afterState.loading.isLoading,
          listCountsChanged: JSON.stringify(beforeState.lists) !== JSON.stringify(afterState.lists)
        };
        
        testResults.stateChanges.push(stateChange);
        
        console.log(`📊 Cambios detectados para ${interaction.name}:`, {
          networkRequests: stateChange.networkRequestsMade,
          loadingChanged: stateChange.loadingStateChanged,
          listsChanged: stateChange.listCountsChanged
        });
        
        // Verificar si hubo actividad de red
        if (stateChange.networkRequestsMade === 0) {
          testResults.issues.push(`❌ ${interaction.name}: No se detectaron requests de red`);
        }
        
        // Verificar si hubo cambios en la UI
        if (!stateChange.loadingStateChanged && !stateChange.listCountsChanged) {
          testResults.issues.push(`❌ ${interaction.name}: No se detectaron cambios en la UI`);
        }
        
      } else {
        console.log(`❌ No se pudo ejecutar ${interaction.name}`);
        testResults.issues.push(`❌ ${interaction.name}: Botón no encontrado`);
      }
      
      // Pausa entre interacciones
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
    
    // 4. Analizar actividad de red
    console.log('\n🌐 3. Analizando actividad de red...');
    const recentRequests = NetworkInterceptor.getRecentRequests(10);
    const supabaseRequests = NetworkInterceptor.getSupabaseRequests();
    
    testResults.networkActivity = {
      totalRequests: recentRequests.length,
      supabaseRequests: supabaseRequests.length,
      failedRequests: recentRequests.filter(req => !req.success).length,
      averageResponseTime: recentRequests.length > 0 
        ? recentRequests.reduce((sum, req) => sum + req.duration, 0) / recentRequests.length 
        : 0
    };
    
    console.log('Actividad de red:', testResults.networkActivity);
    
    if (supabaseRequests.length === 0) {
      testResults.issues.push('❌ No se detectaron requests a Supabase durante las pruebas');
    }
    
    // 5. Verificar estado final
    console.log('\n📊 4. Verificando estado final...');
    const finalState = {
      loading: FlutterStateChecker.checkLoadingStates(),
      errors: FlutterStateChecker.checkErrorStates(),
      lists: FlutterStateChecker.countListItems()
    };
    
    console.log('Estado final:', finalState);
    
    if (finalState.errors.hasErrors) {
      testResults.issues.push('❌ Se detectaron errores en el estado final');
    }
    
  } catch (error) {
    console.error('❌ Error durante la prueba:', error);
    testResults.issues.push(`❌ Error: ${error.message}`);
  }
  
  // 6. Generar reporte
  console.log('\n📋 REPORTE DE REACTIVIDAD DE PROVIDERS');
  console.log('=' .repeat(60));
  
  if (testResults.issues.length === 0) {
    console.log('✅ ¡Todos los providers parecen estar funcionando correctamente!');
  } else {
    console.log('❌ Se encontraron problemas con la reactividad:');
    testResults.issues.forEach(issue => console.log(`  ${issue}`));
  }
  
  console.log('\n📊 Resumen:');
  console.log(`  - Interacciones probadas: ${testResults.stateChanges.length}`);
  console.log(`  - Requests de red: ${testResults.networkActivity.totalRequests}`);
  console.log(`  - Requests a Supabase: ${testResults.networkActivity.supabaseRequests}`);
  console.log(`  - Tiempo promedio de respuesta: ${testResults.networkActivity.averageResponseTime.toFixed(2)}ms`);
  
  return testResults;
}

// Función para monitorear providers en tiempo real
function startProviderMonitoring() {
  console.log('🔄 Iniciando monitoreo de providers en tiempo real...');
  
  NetworkInterceptor.init();
  
  let previousState = {
    loading: FlutterStateChecker.checkLoadingStates(),
    lists: FlutterStateChecker.countListItems(),
    errors: FlutterStateChecker.checkErrorStates()
  };
  
  const monitor = setInterval(() => {
    const currentState = {
      loading: FlutterStateChecker.checkLoadingStates(),
      lists: FlutterStateChecker.countListItems(),
      errors: FlutterStateChecker.checkErrorStates()
    };
    
    // Detectar cambios
    const changes = [];
    
    if (previousState.loading.isLoading !== currentState.loading.isLoading) {
      changes.push(`Loading: ${previousState.loading.isLoading} → ${currentState.loading.isLoading}`);
    }
    
    if (JSON.stringify(previousState.lists) !== JSON.stringify(currentState.lists)) {
      changes.push(`Listas: ${JSON.stringify(previousState.lists)} → ${JSON.stringify(currentState.lists)}`);
    }
    
    if (previousState.errors.hasErrors !== currentState.errors.hasErrors) {
      changes.push(`Errores: ${previousState.errors.hasErrors} → ${currentState.errors.hasErrors}`);
    }
    
    if (changes.length > 0) {
      console.log('🔄 Cambios en providers detectados:');
      changes.forEach(change => console.log(`  ${change}`));
      
      // Verificar requests recientes
      const recentRequests = NetworkInterceptor.getRecentRequests(1);
      if (recentRequests.length > 0) {
        console.log('📡 Requests recientes:', recentRequests);
      }
    }
    
    previousState = currentState;
  }, 2000); // Verificar cada 2 segundos
  
  console.log('✅ Monitoreo de providers iniciado. Para detener, ejecuta: clearInterval(' + monitor + ')');
  return monitor;
}

// Exportar funciones
window.ProviderTester = {
  test: testProviderReactivity,
  monitor: startProviderMonitoring,
  networkInterceptor: NetworkInterceptor,
  stateChecker: FlutterStateChecker
};

console.log('🚀 Script de prueba de reactividad de providers cargado.');
console.log('📋 Comandos disponibles:');
console.log('  - ProviderTester.test() - Ejecutar prueba completa de reactividad');
console.log('  - ProviderTester.monitor() - Iniciar monitoreo en tiempo real');
console.log('  - ProviderTester.stateChecker.* - Verificar estados individuales');
console.log('  - ProviderTester.networkInterceptor.* - Analizar actividad de red');

// Auto-ejecutar si se desea
// testProviderReactivity();