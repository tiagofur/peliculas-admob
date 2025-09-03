/**
 * Diagnóstico completo del sistema de sincronización
 * Ejecutar en la consola del navegador mientras la app Flutter está corriendo
 * 
 * Este script ejecuta todos los tests de diagnóstico y genera un reporte completo
 */

// Configuración global del diagnóstico
const DIAGNOSIS_CONFIG = {
  timeout: 60000, // 1 minuto timeout total
  stepTimeout: 15000, // 15 segundos por paso
  retryAttempts: 2,
  waitBetweenTests: 2000
};

// Resultados globales
let globalResults = {
  timestamp: new Date().toISOString(),
  userAgent: navigator.userAgent,
  url: window.location.href,
  tests: {},
  summary: {
    totalTests: 0,
    passedTests: 0,
    failedTests: 0,
    criticalIssues: [],
    recommendations: []
  }
};

// Utilidades de diagnóstico
const DiagnosisUtils = {
  // Ejecutar con timeout
  async withTimeout(promise, timeoutMs, description) {
    const timeoutPromise = new Promise((_, reject) => {
      setTimeout(() => reject(new Error(`Timeout: ${description}`)), timeoutMs);
    });
    
    try {
      return await Promise.race([promise, timeoutPromise]);
    } catch (error) {
      console.error(`❌ ${description} falló:`, error.message);
      throw error;
    }
  },
  
  // Verificar si un script está cargado
  isScriptLoaded(scriptName) {
    return window[scriptName] !== undefined;
  },
  
  // Cargar script si no está disponible
  async loadScript(scriptPath, scriptName) {
    if (this.isScriptLoaded(scriptName)) {
      return true;
    }
    
    try {
      const response = await fetch(scriptPath);
      const scriptContent = await response.text();
      eval(scriptContent);
      
      // Verificar que se cargó correctamente
      return this.isScriptLoaded(scriptName);
    } catch (error) {
      console.error(`❌ Error cargando script ${scriptPath}:`, error.message);
      return false;
    }
  },
  
  // Analizar resultados de test
  analyzeTestResults(testName, results) {
    const analysis = {
      testName,
      passed: false,
      issues: [],
      recommendations: [],
      score: 0
    };
    
    if (!results) {
      analysis.issues.push('Test no ejecutado o falló completamente');
      return analysis;
    }
    
    // Análisis específico por tipo de test
    switch (testName) {
      case 'auth_sync':
        analysis.passed = results.issues?.length === 0;
        analysis.score = Math.max(0, 100 - (results.issues?.length || 0) * 20);
        if (!analysis.passed) {
          analysis.recommendations.push('Verificar configuración de AuthSyncListener');
          analysis.recommendations.push('Revisar logs de autenticación en Supabase');
        }
        break;
        
      case 'repository_sync':
        analysis.passed = results.issues?.length === 0;
        analysis.score = Math.max(0, 100 - (results.issues?.length || 0) * 15);
        if (!analysis.passed) {
          analysis.recommendations.push('Verificar configuración de repositorios híbridos');
          analysis.recommendations.push('Comprobar sincronización con Supabase');
        }
        break;
        
      case 'provider_reactivity':
        analysis.passed = results.issues?.length === 0;
        analysis.score = Math.max(0, 100 - (results.issues?.length || 0) * 25);
        if (!analysis.passed) {
          analysis.recommendations.push('Verificar que los providers notifiquen cambios correctamente');
          analysis.recommendations.push('Revisar configuración de Riverpod');
        }
        break;
        
      case 'connectivity':
        analysis.passed = results.issues?.length === 0;
        analysis.score = Math.max(0, 100 - (results.issues?.length || 0) * 20);
        if (!analysis.passed) {
          analysis.recommendations.push('Verificar detección de conectividad');
          analysis.recommendations.push('Comprobar manejo de estados offline/online');
        }
        break;
        
      case 'manual_sync':
        analysis.passed = results.success === true && results.issues?.length === 0;
        analysis.score = results.success ? Math.max(0, 100 - (results.issues?.length || 0) * 10) : 0;
        if (!analysis.passed) {
          analysis.recommendations.push('Verificar interacciones de usuario en la UI');
          analysis.recommendations.push('Comprobar actualización de estados en tiempo real');
        }
        break;
        
      default:
        analysis.score = 50; // Score neutro para tests desconocidos
    }
    
    analysis.issues = results.issues || [];
    
    return analysis;
  }
};

// Función principal de diagnóstico completo
async function runCompleteDiagnosis() {
  console.log('🔬 INICIANDO DIAGNÓSTICO COMPLETO DE SINCRONIZACIÓN');
  console.log('=' .repeat(80));
  console.log(`⏰ Iniciado: ${new Date().toLocaleString()}`);
  console.log(`🌐 URL: ${window.location.href}`);
  console.log(`🖥️ User Agent: ${navigator.userAgent}`);
  console.log('=' .repeat(80));
  
  const startTime = Date.now();
  
  try {
    // 1. Test de AuthSyncListener
    console.log('\n🔐 1/5 - Ejecutando diagnóstico de AuthSyncListener...');
    try {
      const authSyncResults = await DiagnosisUtils.withTimeout(
        window.AuthSyncTester?.diagnose() || Promise.resolve({ issues: ['AuthSyncTester no disponible'] }),
        DIAGNOSIS_CONFIG.stepTimeout,
        'Diagnóstico de AuthSyncListener'
      );
      
      globalResults.tests.auth_sync = authSyncResults;
      globalResults.summary.totalTests++;
      
      const authAnalysis = DiagnosisUtils.analyzeTestResults('auth_sync', authSyncResults);
      if (authAnalysis.passed) {
        globalResults.summary.passedTests++;
        console.log('✅ AuthSyncListener: PASÓ');
      } else {
        globalResults.summary.failedTests++;
        console.log('❌ AuthSyncListener: FALLÓ');
        globalResults.summary.criticalIssues.push(...authAnalysis.issues);
      }
      
      globalResults.summary.recommendations.push(...authAnalysis.recommendations);
      
    } catch (error) {
      console.log('❌ AuthSyncListener: ERROR -', error.message);
      globalResults.tests.auth_sync = { issues: [error.message] };
      globalResults.summary.totalTests++;
      globalResults.summary.failedTests++;
    }
    
    await new Promise(resolve => setTimeout(resolve, DIAGNOSIS_CONFIG.waitBetweenTests));
    
    // 2. Test de sincronización de repositorios
    console.log('\n🗄️ 2/5 - Ejecutando diagnóstico de repositorios híbridos...');
    try {
      const repoSyncResults = await DiagnosisUtils.withTimeout(
        window.RepositorySyncTester?.diagnose() || Promise.resolve({ issues: ['RepositorySyncTester no disponible'] }),
        DIAGNOSIS_CONFIG.stepTimeout,
        'Diagnóstico de repositorios híbridos'
      );
      
      globalResults.tests.repository_sync = repoSyncResults;
      globalResults.summary.totalTests++;
      
      const repoAnalysis = DiagnosisUtils.analyzeTestResults('repository_sync', repoSyncResults);
      if (repoAnalysis.passed) {
        globalResults.summary.passedTests++;
        console.log('✅ Repositorios híbridos: PASÓ');
      } else {
        globalResults.summary.failedTests++;
        console.log('❌ Repositorios híbridos: FALLÓ');
        globalResults.summary.criticalIssues.push(...repoAnalysis.issues);
      }
      
      globalResults.summary.recommendations.push(...repoAnalysis.recommendations);
      
    } catch (error) {
      console.log('❌ Repositorios híbridos: ERROR -', error.message);
      globalResults.tests.repository_sync = { issues: [error.message] };
      globalResults.summary.totalTests++;
      globalResults.summary.failedTests++;
    }
    
    await new Promise(resolve => setTimeout(resolve, DIAGNOSIS_CONFIG.waitBetweenTests));
    
    // 3. Test de reactividad de providers
    console.log('\n🔄 3/5 - Ejecutando diagnóstico de reactividad de providers...');
    try {
      const providerResults = await DiagnosisUtils.withTimeout(
        window.ProviderReactivityTester?.diagnose() || Promise.resolve({ issues: ['ProviderReactivityTester no disponible'] }),
        DIAGNOSIS_CONFIG.stepTimeout,
        'Diagnóstico de reactividad de providers'
      );
      
      globalResults.tests.provider_reactivity = providerResults;
      globalResults.summary.totalTests++;
      
      const providerAnalysis = DiagnosisUtils.analyzeTestResults('provider_reactivity', providerResults);
      if (providerAnalysis.passed) {
        globalResults.summary.passedTests++;
        console.log('✅ Reactividad de providers: PASÓ');
      } else {
        globalResults.summary.failedTests++;
        console.log('❌ Reactividad de providers: FALLÓ');
        globalResults.summary.criticalIssues.push(...providerAnalysis.issues);
      }
      
      globalResults.summary.recommendations.push(...providerAnalysis.recommendations);
      
    } catch (error) {
      console.log('❌ Reactividad de providers: ERROR -', error.message);
      globalResults.tests.provider_reactivity = { issues: [error.message] };
      globalResults.summary.totalTests++;
      globalResults.summary.failedTests++;
    }
    
    await new Promise(resolve => setTimeout(resolve, DIAGNOSIS_CONFIG.waitBetweenTests));
    
    // 4. Test de conectividad
    console.log('\n🌐 4/5 - Ejecutando diagnóstico de conectividad...');
    try {
      const connectivityResults = await DiagnosisUtils.withTimeout(
        window.ConnectivityTester?.diagnose() || Promise.resolve({ issues: ['ConnectivityTester no disponible'] }),
        DIAGNOSIS_CONFIG.stepTimeout,
        'Diagnóstico de conectividad'
      );
      
      globalResults.tests.connectivity = connectivityResults;
      globalResults.summary.totalTests++;
      
      const connectivityAnalysis = DiagnosisUtils.analyzeTestResults('connectivity', connectivityResults);
      if (connectivityAnalysis.passed) {
        globalResults.summary.passedTests++;
        console.log('✅ Conectividad: PASÓ');
      } else {
        globalResults.summary.failedTests++;
        console.log('❌ Conectividad: FALLÓ');
        globalResults.summary.criticalIssues.push(...connectivityAnalysis.issues);
      }
      
      globalResults.summary.recommendations.push(...connectivityAnalysis.recommendations);
      
    } catch (error) {
      console.log('❌ Conectividad: ERROR -', error.message);
      globalResults.tests.connectivity = { issues: [error.message] };
      globalResults.summary.totalTests++;
      globalResults.summary.failedTests++;
    }
    
    await new Promise(resolve => setTimeout(resolve, DIAGNOSIS_CONFIG.waitBetweenTests));
    
    // 5. Test manual de sincronización
    console.log('\n🧪 5/5 - Ejecutando test manual de sincronización...');
    try {
      const manualResults = await DiagnosisUtils.withTimeout(
        window.ManualSyncTester?.test() || Promise.resolve({ success: false, issues: ['ManualSyncTester no disponible'] }),
        DIAGNOSIS_CONFIG.stepTimeout,
        'Test manual de sincronización'
      );
      
      globalResults.tests.manual_sync = manualResults;
      globalResults.summary.totalTests++;
      
      const manualAnalysis = DiagnosisUtils.analyzeTestResults('manual_sync', manualResults);
      if (manualAnalysis.passed) {
        globalResults.summary.passedTests++;
        console.log('✅ Test manual: PASÓ');
      } else {
        globalResults.summary.failedTests++;
        console.log('❌ Test manual: FALLÓ');
        globalResults.summary.criticalIssues.push(...manualAnalysis.issues);
      }
      
      globalResults.summary.recommendations.push(...manualAnalysis.recommendations);
      
    } catch (error) {
      console.log('❌ Test manual: ERROR -', error.message);
      globalResults.tests.manual_sync = { success: false, issues: [error.message] };
      globalResults.summary.totalTests++;
      globalResults.summary.failedTests++;
    }
    
  } catch (error) {
    console.error('❌ Error crítico durante el diagnóstico:', error);
    globalResults.summary.criticalIssues.push(`Error crítico: ${error.message}`);
  }
  
  const endTime = Date.now();
  const duration = endTime - startTime;
  
  // Generar reporte final
  generateFinalReport(duration);
  
  return globalResults;
}

// Generar reporte final
function generateFinalReport(duration) {
  console.log('\n📋 REPORTE FINAL DE DIAGNÓSTICO DE SINCRONIZACIÓN');
  console.log('=' .repeat(80));
  
  // Estadísticas generales
  const successRate = globalResults.summary.totalTests > 0 
    ? (globalResults.summary.passedTests / globalResults.summary.totalTests * 100).toFixed(1)
    : 0;
  
  console.log(`⏱️ Duración total: ${(duration / 1000).toFixed(1)} segundos`);
  console.log(`📊 Tests ejecutados: ${globalResults.summary.totalTests}`);
  console.log(`✅ Tests exitosos: ${globalResults.summary.passedTests}`);
  console.log(`❌ Tests fallidos: ${globalResults.summary.failedTests}`);
  console.log(`📈 Tasa de éxito: ${successRate}%`);
  
  // Estado general del sistema
  console.log('\n🎯 ESTADO GENERAL DEL SISTEMA:');
  if (successRate >= 80) {
    console.log('🟢 EXCELENTE - El sistema de sincronización funciona correctamente');
  } else if (successRate >= 60) {
    console.log('🟡 ACEPTABLE - El sistema funciona pero tiene algunos problemas menores');
  } else if (successRate >= 40) {
    console.log('🟠 PROBLEMÁTICO - El sistema tiene problemas significativos que requieren atención');
  } else {
    console.log('🔴 CRÍTICO - El sistema de sincronización tiene problemas graves');
  }
  
  // Problemas críticos
  if (globalResults.summary.criticalIssues.length > 0) {
    console.log('\n🚨 PROBLEMAS CRÍTICOS ENCONTRADOS:');
    globalResults.summary.criticalIssues.forEach((issue, index) => {
      console.log(`  ${index + 1}. ${issue}`);
    });
  }
  
  // Recomendaciones
  if (globalResults.summary.recommendations.length > 0) {
    console.log('\n💡 RECOMENDACIONES:');
    const uniqueRecommendations = [...new Set(globalResults.summary.recommendations)];
    uniqueRecommendations.forEach((rec, index) => {
      console.log(`  ${index + 1}. ${rec}`);
    });
  }
  
  // Detalles por test
  console.log('\n📝 DETALLES POR TEST:');
  Object.entries(globalResults.tests).forEach(([testName, results]) => {
    const analysis = DiagnosisUtils.analyzeTestResults(testName, results);
    const status = analysis.passed ? '✅' : '❌';
    console.log(`  ${status} ${testName.toUpperCase()}: Score ${analysis.score}/100`);
    
    if (analysis.issues.length > 0) {
      analysis.issues.forEach(issue => {
        console.log(`    - ${issue}`);
      });
    }
  });
  
  // Próximos pasos
  console.log('\n🎯 PRÓXIMOS PASOS RECOMENDADOS:');
  if (successRate < 80) {
    console.log('  1. Revisar y corregir los problemas críticos listados arriba');
    console.log('  2. Verificar la configuración de Supabase y las claves de API');
    console.log('  3. Comprobar la conectividad de red y la configuración de CORS');
    console.log('  4. Revisar los logs de la aplicación para errores adicionales');
    console.log('  5. Ejecutar este diagnóstico nuevamente después de las correcciones');
  } else {
    console.log('  1. Monitorear el sistema regularmente');
    console.log('  2. Implementar tests automatizados basados en este diagnóstico');
    console.log('  3. Considerar optimizaciones de rendimiento si es necesario');
  }
  
  console.log('\n' + '=' .repeat(80));
  console.log('📄 Reporte completo guardado en: window.SyncDiagnosisResults');
  console.log('🔄 Para ejecutar nuevamente: runCompleteDiagnosis()');
}

// Función para obtener resumen rápido
function getQuickSummary() {
  if (!globalResults.summary.totalTests) {
    console.log('⚠️ No hay resultados disponibles. Ejecuta runCompleteDiagnosis() primero.');
    return null;
  }
  
  const successRate = (globalResults.summary.passedTests / globalResults.summary.totalTests * 100).toFixed(1);
  
  console.log('📊 RESUMEN RÁPIDO:');
  console.log(`  Tasa de éxito: ${successRate}%`);
  console.log(`  Problemas críticos: ${globalResults.summary.criticalIssues.length}`);
  console.log(`  Recomendaciones: ${globalResults.summary.recommendations.length}`);
  
  return {
    successRate: parseFloat(successRate),
    criticalIssues: globalResults.summary.criticalIssues.length,
    recommendations: globalResults.summary.recommendations.length,
    status: successRate >= 80 ? 'excellent' : successRate >= 60 ? 'good' : successRate >= 40 ? 'problematic' : 'critical'
  };
}

// Exportar funciones y resultados
window.SyncDiagnosisResults = globalResults;
window.CompleteSyncDiagnosis = {
  run: runCompleteDiagnosis,
  getResults: () => globalResults,
  getSummary: getQuickSummary,
  utils: DiagnosisUtils
};

console.log('🚀 Diagnóstico completo de sincronización cargado.');
console.log('📋 Comandos disponibles:');
console.log('  - runCompleteDiagnosis() - Ejecutar diagnóstico completo');
console.log('  - CompleteSyncDiagnosis.getSummary() - Obtener resumen rápido');
console.log('  - CompleteSyncDiagnosis.getResults() - Obtener resultados completos');
console.log('\n🎯 Para iniciar el diagnóstico completo, ejecuta: runCompleteDiagnosis()');

// Auto-ejecutar si se desea
// runCompleteDiagnosis();