/**
 * Script de diagnóstico para verificar actualizaciones de UI en providers
 * Ejecutar en la consola del navegador mientras la app Flutter está corriendo
 */

// Configuración de prueba
const TEST_CONFIG = {
  testMovieId: 550, // Fight Club - película de prueba
  testMovie: {
    id: 550,
    title: "Fight Club",
    overview: "Película de prueba para diagnóstico",
    poster_path: "/test.jpg",
    release_date: "1999-10-15",
    vote_average: 8.8
  },
  delayBetweenActions: 2000 // 2 segundos entre acciones
};

// Utilidades para interactuar con Flutter
const FlutterUtils = {
  // Simular click en botón de favoritos
  clickFavoriteButton: () => {
    const favoriteBtn = document.querySelector('[data-testid="favorite-button"], .favorite-button, button[title*="favorito"], button[aria-label*="favorito"]');
    if (favoriteBtn) {
      favoriteBtn.click();
      console.log('✅ Click en botón de favoritos simulado');
      return true;
    }
    console.log('❌ No se encontró botón de favoritos');
    return false;
  },

  // Simular click en botón de watchlist
  clickWatchlistButton: () => {
    const watchlistBtn = document.querySelector('[data-testid="watchlist-button"], .watchlist-button, button[title*="watchlist"], button[aria-label*="watchlist"]');
    if (watchlistBtn) {
      watchlistBtn.click();
      console.log('✅ Click en botón de watchlist simulado');
      return true;
    }
    console.log('❌ No se encontró botón de watchlist');
    return false;
  },

  // Simular marcar como vista
  clickWatchedButton: () => {
    const watchedBtn = document.querySelector('[data-testid="watched-button"], .watched-button, button[title*="vista"], button[aria-label*="vista"]');
    if (watchedBtn) {
      watchedBtn.click();
      console.log('✅ Click en botón de película vista simulado');
      return true;
    }
    console.log('❌ No se encontró botón de película vista');
    return false;
  },

  // Verificar cambios en la UI
  checkUIChanges: () => {
    const results = {
      favoriteButtonState: null,
      watchlistButtonState: null,
      watchedButtonState: null,
      counters: {
        favorites: null,
        watchlist: null,
        watched: null
      }
    };

    // Verificar estado de botones
    const favoriteBtn = document.querySelector('[data-testid="favorite-button"], .favorite-button');
    if (favoriteBtn) {
      results.favoriteButtonState = favoriteBtn.classList.contains('active') || favoriteBtn.getAttribute('aria-pressed') === 'true';
    }

    const watchlistBtn = document.querySelector('[data-testid="watchlist-button"], .watchlist-button');
    if (watchlistBtn) {
      results.watchlistButtonState = watchlistBtn.classList.contains('active') || watchlistBtn.getAttribute('aria-pressed') === 'true';
    }

    const watchedBtn = document.querySelector('[data-testid="watched-button"], .watched-button');
    if (watchedBtn) {
      results.watchedButtonState = watchedBtn.classList.contains('active') || watchedBtn.getAttribute('aria-pressed') === 'true';
    }

    // Verificar contadores en la UI
    const favoriteCounter = document.querySelector('[data-testid="favorites-count"], .favorites-count');
    if (favoriteCounter) {
      results.counters.favorites = parseInt(favoriteCounter.textContent) || 0;
    }

    const watchlistCounter = document.querySelector('[data-testid="watchlist-count"], .watchlist-count');
    if (watchlistCounter) {
      results.counters.watchlist = parseInt(watchlistCounter.textContent) || 0;
    }

    const watchedCounter = document.querySelector('[data-testid="watched-count"], .watched-count');
    if (watchedCounter) {
      results.counters.watched = parseInt(watchedCounter.textContent) || 0;
    }

    return results;
  },

  // Navegar a diferentes secciones
  navigateToFavorites: () => {
    const favoritesLink = document.querySelector('a[href*="favorites"], button[data-route="favorites"]');
    if (favoritesLink) {
      favoritesLink.click();
      console.log('✅ Navegando a favoritos');
      return true;
    }
    console.log('❌ No se encontró enlace a favoritos');
    return false;
  },

  navigateToWatchlist: () => {
    const watchlistLink = document.querySelector('a[href*="watchlist"], button[data-route="watchlist"]');
    if (watchlistLink) {
      watchlistLink.click();
      console.log('✅ Navegando a watchlist');
      return true;
    }
    console.log('❌ No se encontró enlace a watchlist');
    return false;
  },

  navigateToWatched: () => {
    const watchedLink = document.querySelector('a[href*="watched"], button[data-route="watched"]');
    if (watchedLink) {
      watchedLink.click();
      console.log('✅ Navegando a películas vistas');
      return true;
    }
    console.log('❌ No se encontró enlace a películas vistas');
    return false;
  }
};

// Función principal de diagnóstico
async function diagnoseUIUpdates() {
  console.log('🔍 INICIANDO DIAGNÓSTICO DE ACTUALIZACIONES DE UI');
  console.log('=' .repeat(60));

  const results = {
    initialState: null,
    afterFavoriteToggle: null,
    afterWatchlistToggle: null,
    afterWatchedToggle: null,
    navigationTests: {
      favorites: false,
      watchlist: false,
      watched: false
    },
    issues: []
  };

  try {
    // 1. Capturar estado inicial
    console.log('\n📊 1. Capturando estado inicial de la UI...');
    results.initialState = FlutterUtils.checkUIChanges();
    console.log('Estado inicial:', results.initialState);

    await new Promise(resolve => setTimeout(resolve, TEST_CONFIG.delayBetweenActions));

    // 2. Probar toggle de favoritos
    console.log('\n❤️ 2. Probando toggle de favoritos...');
    if (FlutterUtils.clickFavoriteButton()) {
      await new Promise(resolve => setTimeout(resolve, TEST_CONFIG.delayBetweenActions));
      results.afterFavoriteToggle = FlutterUtils.checkUIChanges();
      console.log('Estado después de toggle favoritos:', results.afterFavoriteToggle);
      
      // Verificar si cambió el estado
      if (results.initialState.favoriteButtonState === results.afterFavoriteToggle.favoriteButtonState) {
        results.issues.push('❌ El botón de favoritos no cambió de estado');
      } else {
        console.log('✅ El botón de favoritos cambió correctamente');
      }
    } else {
      results.issues.push('❌ No se pudo hacer click en el botón de favoritos');
    }

    await new Promise(resolve => setTimeout(resolve, TEST_CONFIG.delayBetweenActions));

    // 3. Probar toggle de watchlist
    console.log('\n📋 3. Probando toggle de watchlist...');
    if (FlutterUtils.clickWatchlistButton()) {
      await new Promise(resolve => setTimeout(resolve, TEST_CONFIG.delayBetweenActions));
      results.afterWatchlistToggle = FlutterUtils.checkUIChanges();
      console.log('Estado después de toggle watchlist:', results.afterWatchlistToggle);
      
      // Verificar si cambió el estado
      if (results.afterFavoriteToggle && results.afterFavoriteToggle.watchlistButtonState === results.afterWatchlistToggle.watchlistButtonState) {
        results.issues.push('❌ El botón de watchlist no cambió de estado');
      } else {
        console.log('✅ El botón de watchlist cambió correctamente');
      }
    } else {
      results.issues.push('❌ No se pudo hacer click en el botón de watchlist');
    }

    await new Promise(resolve => setTimeout(resolve, TEST_CONFIG.delayBetweenActions));

    // 4. Probar marcar como vista
    console.log('\n👁️ 4. Probando marcar como vista...');
    if (FlutterUtils.clickWatchedButton()) {
      await new Promise(resolve => setTimeout(resolve, TEST_CONFIG.delayBetweenActions));
      results.afterWatchedToggle = FlutterUtils.checkUIChanges();
      console.log('Estado después de marcar como vista:', results.afterWatchedToggle);
      
      // Verificar si cambió el estado
      if (results.afterWatchlistToggle && results.afterWatchlistToggle.watchedButtonState === results.afterWatchedToggle.watchedButtonState) {
        results.issues.push('❌ El botón de película vista no cambió de estado');
      } else {
        console.log('✅ El botón de película vista cambió correctamente');
      }
    } else {
      results.issues.push('❌ No se pudo hacer click en el botón de película vista');
    }

    await new Promise(resolve => setTimeout(resolve, TEST_CONFIG.delayBetweenActions));

    // 5. Probar navegación y verificar listas
    console.log('\n🧭 5. Probando navegación a diferentes secciones...');
    
    // Probar navegación a favoritos
    if (FlutterUtils.navigateToFavorites()) {
      await new Promise(resolve => setTimeout(resolve, TEST_CONFIG.delayBetweenActions));
      results.navigationTests.favorites = true;
      console.log('✅ Navegación a favoritos exitosa');
    }

    // Probar navegación a watchlist
    if (FlutterUtils.navigateToWatchlist()) {
      await new Promise(resolve => setTimeout(resolve, TEST_CONFIG.delayBetweenActions));
      results.navigationTests.watchlist = true;
      console.log('✅ Navegación a watchlist exitosa');
    }

    // Probar navegación a películas vistas
    if (FlutterUtils.navigateToWatched()) {
      await new Promise(resolve => setTimeout(resolve, TEST_CONFIG.delayBetweenActions));
      results.navigationTests.watched = true;
      console.log('✅ Navegación a películas vistas exitosa');
    }

  } catch (error) {
    console.error('❌ Error durante el diagnóstico:', error);
    results.issues.push(`❌ Error: ${error.message}`);
  }

  // 6. Generar reporte final
  console.log('\n📋 REPORTE FINAL DE DIAGNÓSTICO');
  console.log('=' .repeat(60));
  
  if (results.issues.length === 0) {
    console.log('✅ ¡Todas las pruebas de UI pasaron correctamente!');
  } else {
    console.log('❌ Se encontraron los siguientes problemas:');
    results.issues.forEach(issue => console.log(`  ${issue}`));
  }

  console.log('\n📊 Resumen de estados:');
  console.log('  - Estado inicial:', results.initialState);
  console.log('  - Después de favoritos:', results.afterFavoriteToggle);
  console.log('  - Después de watchlist:', results.afterWatchlistToggle);
  console.log('  - Después de marcar vista:', results.afterWatchedToggle);
  console.log('  - Navegación exitosa:', results.navigationTests);

  return results;
}

// Función para monitorear cambios en tiempo real
function startUIMonitoring() {
  console.log('🔄 Iniciando monitoreo de UI en tiempo real...');
  
  let previousState = FlutterUtils.checkUIChanges();
  
  const monitor = setInterval(() => {
    const currentState = FlutterUtils.checkUIChanges();
    
    // Comparar estados
    const changes = [];
    
    if (previousState.favoriteButtonState !== currentState.favoriteButtonState) {
      changes.push(`Favoritos: ${previousState.favoriteButtonState} → ${currentState.favoriteButtonState}`);
    }
    
    if (previousState.watchlistButtonState !== currentState.watchlistButtonState) {
      changes.push(`Watchlist: ${previousState.watchlistButtonState} → ${currentState.watchlistButtonState}`);
    }
    
    if (previousState.watchedButtonState !== currentState.watchedButtonState) {
      changes.push(`Vistas: ${previousState.watchedButtonState} → ${currentState.watchedButtonState}`);
    }
    
    if (previousState.counters.favorites !== currentState.counters.favorites) {
      changes.push(`Contador favoritos: ${previousState.counters.favorites} → ${currentState.counters.favorites}`);
    }
    
    if (previousState.counters.watchlist !== currentState.counters.watchlist) {
      changes.push(`Contador watchlist: ${previousState.counters.watchlist} → ${currentState.counters.watchlist}`);
    }
    
    if (previousState.counters.watched !== currentState.counters.watched) {
      changes.push(`Contador vistas: ${previousState.counters.watched} → ${currentState.counters.watched}`);
    }
    
    if (changes.length > 0) {
      console.log('🔄 Cambios detectados en la UI:');
      changes.forEach(change => console.log(`  ${change}`));
    }
    
    previousState = currentState;
  }, 1000); // Verificar cada segundo
  
  console.log('✅ Monitoreo iniciado. Para detener, ejecuta: clearInterval(' + monitor + ')');
  return monitor;
}

// Exportar funciones para uso manual
window.UITester = {
  diagnose: diagnoseUIUpdates,
  monitor: startUIMonitoring,
  utils: FlutterUtils,
  checkState: FlutterUtils.checkUIChanges
};

console.log('🚀 Script de diagnóstico de UI cargado.');
console.log('📋 Comandos disponibles:');
console.log('  - UITester.diagnose() - Ejecutar diagnóstico completo');
console.log('  - UITester.monitor() - Iniciar monitoreo en tiempo real');
console.log('  - UITester.checkState() - Verificar estado actual');
console.log('  - UITester.utils.* - Utilidades individuales');

// Auto-ejecutar diagnóstico si se desea
// diagnoseUIUpdates();