/**
 * Script para probar manualmente la sincronización con datos de prueba
 * Ejecutar en la consola del navegador mientras la app Flutter está corriendo
 */

// Configuración del test manual
const MANUAL_SYNC_CONFIG = {
  testMovieId: 550, // Fight Club - película de prueba
  testMovieData: {
    id: 550,
    title: 'Fight Club',
    poster_path: '/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg',
    overview: 'A ticking-time-bomb insomniac and a slippery soap salesman channel primal male aggression into a shocking new form of therapy.',
    release_date: '1999-10-15',
    vote_average: 8.433
  },
  waitTime: 3000, // Tiempo de espera entre acciones
  maxRetries: 3
};

// Utilidades para interactuar con la UI
const UIInteractor = {
  // Buscar elementos por diferentes selectores
  findElement(selectors) {
    for (const selector of selectors) {
      const element = document.querySelector(selector);
      if (element) return element;
    }
    return null;
  },
  
  // Buscar múltiples elementos
  findElements(selectors) {
    const elements = [];
    for (const selector of selectors) {
      elements.push(...document.querySelectorAll(selector));
    }
    return elements;
  },
  
  // Simular click en elemento
  async clickElement(element, description = '') {
    if (!element) {
      console.log(`❌ No se pudo hacer click: elemento no encontrado ${description}`);
      return false;
    }
    
    try {
      // Scroll al elemento si es necesario
      element.scrollIntoView({ behavior: 'smooth', block: 'center' });
      await new Promise(resolve => setTimeout(resolve, 500));
      
      // Simular click
      element.click();
      console.log(`✅ Click realizado ${description}`);
      
      // Esperar a que se procese
      await new Promise(resolve => setTimeout(resolve, MANUAL_SYNC_CONFIG.waitTime));
      return true;
    } catch (error) {
      console.log(`❌ Error al hacer click ${description}:`, error.message);
      return false;
    }
  },
  
  // Obtener texto de elemento
  getElementText(element) {
    if (!element) return null;
    return element.textContent?.trim() || element.innerText?.trim() || null;
  },
  
  // Verificar si elemento está visible
  isElementVisible(element) {
    if (!element) return false;
    const rect = element.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0 && 
           window.getComputedStyle(element).visibility !== 'hidden' &&
           window.getComputedStyle(element).display !== 'none';
  }
};

// Monitor de cambios en la UI
const UIChangeMonitor = {
  snapshots: [],
  
  // Tomar snapshot del estado actual
  takeSnapshot(label = '') {
    const snapshot = {
      label,
      timestamp: new Date().toISOString(),
      counts: {
        favoriteButtons: this.countFavoriteButtons(),
        watchlistButtons: this.countWatchlistButtons(),
        watchedButtons: this.countWatchedButtons(),
        movieCards: document.querySelectorAll('.movie-card, [data-testid*="movie"]').length,
        loadingIndicators: document.querySelectorAll('.loading, .spinner, [data-testid*="loading"]').length,
        errorMessages: document.querySelectorAll('.error, [data-testid*="error"]').length
      },
      states: {
        favoriteStates: this.getFavoriteStates(),
        watchlistStates: this.getWatchlistStates(),
        watchedStates: this.getWatchedStates()
      },
      listCounts: this.getListCounts()
    };
    
    this.snapshots.push(snapshot);
    console.log(`📸 Snapshot tomado: ${label}`, snapshot);
    return snapshot;
  },
  
  // Contar botones de favoritos
  countFavoriteButtons() {
    const selectors = [
      'button[data-testid*="favorite"]',
      '.favorite-button',
      'button:has(.heart)',
      'button:has([data-icon="heart"])',
      'flt-semantics[aria-label*="favorit"]'
    ];
    return UIInteractor.findElements(selectors).length;
  },
  
  // Contar botones de watchlist
  countWatchlistButtons() {
    const selectors = [
      'button[data-testid*="watchlist"]',
      '.watchlist-button',
      'button:has(.bookmark)',
      'button:has([data-icon="bookmark"])',
      'flt-semantics[aria-label*="watchlist"]'
    ];
    return UIInteractor.findElements(selectors).length;
  },
  
  // Contar botones de visto
  countWatchedButtons() {
    const selectors = [
      'button[data-testid*="watched"]',
      '.watched-button',
      'button:has(.check)',
      'button:has([data-icon="check"])',
      'flt-semantics[aria-label*="watched"]',
      'flt-semantics[aria-label*="visto"]'
    ];
    return UIInteractor.findElements(selectors).length;
  },
  
  // Obtener estados de favoritos
  getFavoriteStates() {
    const buttons = UIInteractor.findElements([
      'button[data-testid*="favorite"]',
      '.favorite-button',
      'flt-semantics[aria-label*="favorit"]'
    ]);
    
    return buttons.map(btn => ({
      text: UIInteractor.getElementText(btn),
      ariaLabel: btn.getAttribute('aria-label'),
      classes: btn.className,
      pressed: btn.getAttribute('aria-pressed') === 'true'
    }));
  },
  
  // Obtener estados de watchlist
  getWatchlistStates() {
    const buttons = UIInteractor.findElements([
      'button[data-testid*="watchlist"]',
      '.watchlist-button',
      'flt-semantics[aria-label*="watchlist"]'
    ]);
    
    return buttons.map(btn => ({
      text: UIInteractor.getElementText(btn),
      ariaLabel: btn.getAttribute('aria-label'),
      classes: btn.className,
      pressed: btn.getAttribute('aria-pressed') === 'true'
    }));
  },
  
  // Obtener estados de visto
  getWatchedStates() {
    const buttons = UIInteractor.findElements([
      'button[data-testid*="watched"]',
      '.watched-button',
      'flt-semantics[aria-label*="watched"]',
      'flt-semantics[aria-label*="visto"]'
    ]);
    
    return buttons.map(btn => ({
      text: UIInteractor.getElementText(btn),
      ariaLabel: btn.getAttribute('aria-label'),
      classes: btn.className,
      pressed: btn.getAttribute('aria-pressed') === 'true'
    }));
  },
  
  // Obtener contadores de listas
  getListCounts() {
    const counters = {};
    
    // Buscar elementos que muestren contadores
    const counterElements = UIInteractor.findElements([
      '.count',
      '.counter',
      '[data-testid*="count"]',
      '.badge',
      '.chip'
    ]);
    
    counterElements.forEach((el, index) => {
      const text = UIInteractor.getElementText(el);
      if (text && /\d+/.test(text)) {
        counters[`counter_${index}`] = text;
      }
    });
    
    return counters;
  },
  
  // Comparar snapshots
  compareSnapshots(snapshot1, snapshot2) {
    const changes = {
      countsChanged: JSON.stringify(snapshot1.counts) !== JSON.stringify(snapshot2.counts),
      statesChanged: JSON.stringify(snapshot1.states) !== JSON.stringify(snapshot2.states),
      listCountsChanged: JSON.stringify(snapshot1.listCounts) !== JSON.stringify(snapshot2.listCounts),
      details: {
        countDiffs: {},
        stateDiffs: {},
        listCountDiffs: {}
      }
    };
    
    // Comparar contadores
    Object.keys(snapshot1.counts).forEach(key => {
      if (snapshot1.counts[key] !== snapshot2.counts[key]) {
        changes.details.countDiffs[key] = {
          before: snapshot1.counts[key],
          after: snapshot2.counts[key]
        };
      }
    });
    
    // Comparar contadores de listas
    const allListKeys = new Set([...Object.keys(snapshot1.listCounts), ...Object.keys(snapshot2.listCounts)]);
    allListKeys.forEach(key => {
      if (snapshot1.listCounts[key] !== snapshot2.listCounts[key]) {
        changes.details.listCountDiffs[key] = {
          before: snapshot1.listCounts[key] || 'undefined',
          after: snapshot2.listCounts[key] || 'undefined'
        };
      }
    });
    
    return changes;
  },
  
  // Limpiar snapshots
  clearSnapshots() {
    this.snapshots = [];
  }
};

// Función principal de test manual
async function testManualSync() {
  console.log('🧪 INICIANDO TEST MANUAL DE SINCRONIZACIÓN');
  console.log('=' .repeat(70));
  
  const results = {
    initialState: null,
    actions: [],
    finalState: null,
    issues: [],
    success: false
  };
  
  try {
    // 1. Tomar snapshot inicial
    console.log('\n📸 1. Capturando estado inicial...');
    UIChangeMonitor.clearSnapshots();
    results.initialState = UIChangeMonitor.takeSnapshot('Estado inicial');
    
    // 2. Buscar película de prueba o usar la primera disponible
    console.log('\n🔍 2. Buscando película para probar...');
    
    const movieCards = UIInteractor.findElements([
      '.movie-card',
      '[data-testid*="movie"]',
      '.movie-item',
      'flt-semantics:has(img)'
    ]);
    
    if (movieCards.length === 0) {
      results.issues.push('❌ No se encontraron tarjetas de películas en la UI');
      console.log('❌ No hay películas disponibles para probar');
      return results;
    }
    
    console.log(`✅ Encontradas ${movieCards.length} películas disponibles`);
    const testMovieCard = movieCards[0]; // Usar la primera película
    
    // 3. Probar botón de favoritos
    console.log('\n❤️ 3. Probando funcionalidad de favoritos...');
    
    const favoriteButton = testMovieCard.querySelector('button[data-testid*="favorite"], .favorite-button') ||
                          UIInteractor.findElement([
                            'button[data-testid*="favorite"]',
                            '.favorite-button',
                            'flt-semantics[aria-label*="favorit"]'
                          ]);
    
    if (favoriteButton) {
      const beforeFavorite = UIChangeMonitor.takeSnapshot('Antes de favorito');
      const favoriteSuccess = await UIInteractor.clickElement(favoriteButton, '(botón favorito)');
      
      if (favoriteSuccess) {
        const afterFavorite = UIChangeMonitor.takeSnapshot('Después de favorito');
        const favoriteChanges = UIChangeMonitor.compareSnapshots(beforeFavorite, afterFavorite);
        
        results.actions.push({
          action: 'toggle_favorite',
          success: favoriteSuccess,
          changes: favoriteChanges
        });
        
        if (!favoriteChanges.countsChanged && !favoriteChanges.statesChanged) {
          results.issues.push('❌ El botón de favoritos no produjo cambios visibles en la UI');
        }
      } else {
        results.issues.push('❌ No se pudo hacer click en el botón de favoritos');
      }
    } else {
      results.issues.push('❌ No se encontró botón de favoritos');
    }
    
    // 4. Probar botón de watchlist
    console.log('\n🔖 4. Probando funcionalidad de watchlist...');
    
    const watchlistButton = testMovieCard.querySelector('button[data-testid*="watchlist"], .watchlist-button') ||
                           UIInteractor.findElement([
                             'button[data-testid*="watchlist"]',
                             '.watchlist-button',
                             'flt-semantics[aria-label*="watchlist"]'
                           ]);
    
    if (watchlistButton) {
      const beforeWatchlist = UIChangeMonitor.takeSnapshot('Antes de watchlist');
      const watchlistSuccess = await UIInteractor.clickElement(watchlistButton, '(botón watchlist)');
      
      if (watchlistSuccess) {
        const afterWatchlist = UIChangeMonitor.takeSnapshot('Después de watchlist');
        const watchlistChanges = UIChangeMonitor.compareSnapshots(beforeWatchlist, afterWatchlist);
        
        results.actions.push({
          action: 'toggle_watchlist',
          success: watchlistSuccess,
          changes: watchlistChanges
        });
        
        if (!watchlistChanges.countsChanged && !watchlistChanges.statesChanged) {
          results.issues.push('❌ El botón de watchlist no produjo cambios visibles en la UI');
        }
      } else {
        results.issues.push('❌ No se pudo hacer click en el botón de watchlist');
      }
    } else {
      results.issues.push('❌ No se encontró botón de watchlist');
    }
    
    // 5. Probar botón de visto
    console.log('\n✅ 5. Probando funcionalidad de visto...');
    
    const watchedButton = testMovieCard.querySelector('button[data-testid*="watched"], .watched-button') ||
                         UIInteractor.findElement([
                           'button[data-testid*="watched"]',
                           '.watched-button',
                           'flt-semantics[aria-label*="watched"]',
                           'flt-semantics[aria-label*="visto"]'
                         ]);
    
    if (watchedButton) {
      const beforeWatched = UIChangeMonitor.takeSnapshot('Antes de visto');
      const watchedSuccess = await UIInteractor.clickElement(watchedButton, '(botón visto)');
      
      if (watchedSuccess) {
        const afterWatched = UIChangeMonitor.takeSnapshot('Después de visto');
        const watchedChanges = UIChangeMonitor.compareSnapshots(beforeWatched, afterWatched);
        
        results.actions.push({
          action: 'toggle_watched',
          success: watchedSuccess,
          changes: watchedChanges
        });
        
        if (!watchedChanges.countsChanged && !watchedChanges.statesChanged) {
          results.issues.push('❌ El botón de visto no produjo cambios visibles en la UI');
        }
      } else {
        results.issues.push('❌ No se pudo hacer click en el botón de visto');
      }
    } else {
      results.issues.push('❌ No se encontró botón de visto');
    }
    
    // 6. Navegar entre secciones para verificar persistencia
    console.log('\n🧭 6. Probando navegación y persistencia...');
    
    const navigationButtons = UIInteractor.findElements([
      'button[data-testid*="nav"]',
      '.nav-button',
      '.tab-button',
      'flt-semantics[role="tab"]',
      'a[href*="favorites"]',
      'a[href*="watchlist"]',
      'a[href*="watched"]'
    ]);
    
    if (navigationButtons.length > 0) {
      for (let i = 0; i < Math.min(3, navigationButtons.length); i++) {
        const navButton = navigationButtons[i];
        const navText = UIInteractor.getElementText(navButton) || `Navegación ${i + 1}`;
        
        const beforeNav = UIChangeMonitor.takeSnapshot(`Antes de navegar a ${navText}`);
        const navSuccess = await UIInteractor.clickElement(navButton, `(navegación a ${navText})`);
        
        if (navSuccess) {
          const afterNav = UIChangeMonitor.takeSnapshot(`Después de navegar a ${navText}`);
          const navChanges = UIChangeMonitor.compareSnapshots(beforeNav, afterNav);
          
          results.actions.push({
            action: 'navigation',
            target: navText,
            success: navSuccess,
            changes: navChanges
          });
        }
      }
    } else {
      results.issues.push('❌ No se encontraron botones de navegación');
    }
    
    // 7. Tomar snapshot final
    console.log('\n📸 7. Capturando estado final...');
    results.finalState = UIChangeMonitor.takeSnapshot('Estado final');
    
    // 8. Verificar si hubo cambios persistentes
    const overallChanges = UIChangeMonitor.compareSnapshots(results.initialState, results.finalState);
    
    if (overallChanges.countsChanged || overallChanges.statesChanged || overallChanges.listCountsChanged) {
      console.log('✅ Se detectaron cambios persistentes en la UI');
      results.success = true;
    } else {
      results.issues.push('❌ No se detectaron cambios persistentes después de las acciones');
    }
    
  } catch (error) {
    console.error('❌ Error durante el test manual:', error);
    results.issues.push(`❌ Error: ${error.message}`);
  }
  
  // 9. Generar reporte final
  console.log('\n📋 REPORTE DE TEST MANUAL DE SINCRONIZACIÓN');
  console.log('=' .repeat(70));
  
  if (results.success && results.issues.length === 0) {
    console.log('✅ ¡El test manual de sincronización fue exitoso!');
  } else {
    console.log('❌ Se encontraron problemas durante el test:');
    results.issues.forEach(issue => console.log(`  ${issue}`));
  }
  
  console.log('\n📊 Resumen de acciones:');
  results.actions.forEach((action, index) => {
    const status = action.success ? '✅' : '❌';
    console.log(`  ${index + 1}. ${status} ${action.action} ${action.target ? `(${action.target})` : ''}`);
  });
  
  console.log('\n📈 Snapshots capturados:', UIChangeMonitor.snapshots.length);
  
  return results;
}

// Función para verificar estado actual
function checkCurrentState() {
  console.log('🔍 VERIFICANDO ESTADO ACTUAL DE LA UI');
  console.log('=' .repeat(50));
  
  const currentSnapshot = UIChangeMonitor.takeSnapshot('Estado actual');
  
  console.log('📊 Contadores encontrados:');
  Object.entries(currentSnapshot.counts).forEach(([key, value]) => {
    console.log(`  ${key}: ${value}`);
  });
  
  console.log('\n🎬 Estados de botones:');
  console.log('  Favoritos:', currentSnapshot.states.favoriteStates.length);
  console.log('  Watchlist:', currentSnapshot.states.watchlistStates.length);
  console.log('  Visto:', currentSnapshot.states.watchedStates.length);
  
  console.log('\n📋 Contadores de listas:');
  Object.entries(currentSnapshot.listCounts).forEach(([key, value]) => {
    console.log(`  ${key}: ${value}`);
  });
  
  return currentSnapshot;
}

// Exportar funciones
window.ManualSyncTester = {
  test: testManualSync,
  checkState: checkCurrentState,
  monitor: UIChangeMonitor,
  interactor: UIInteractor
};

console.log('🚀 Script de test manual de sincronización cargado.');
console.log('📋 Comandos disponibles:');
console.log('  - ManualSyncTester.test() - Ejecutar test completo');
console.log('  - ManualSyncTester.checkState() - Verificar estado actual');
console.log('  - ManualSyncTester.monitor.* - Acceder al monitor de cambios');
console.log('  - ManualSyncTester.interactor.* - Acceder al interactor de UI');

// Auto-ejecutar si se des