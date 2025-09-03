/**
 * Script para debuggear repositorios híbridos y sincronización
 * Verifica el estado actual de los datos y detecta inconsistencias
 */

const { createClient } = require('@supabase/supabase-js');

// Configuración de Supabase
const supabaseUrl = 'https://fyzujpifkzftweynrudh.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTkxOTgsImV4cCI6MjA3MDkzNTE5OH0.-wnFtwyfKuasSJ9GDvhOgKLgfz-clpqnMF1u-lC8sBg';

// Crear cliente de Supabase
const supabase = createClient(supabaseUrl, supabaseKey);

async function debugHybridRepositories() {
  console.log('🔍 Iniciando debug de repositorios híbridos...');
  
  try {
    // 1. Verificar autenticación
    console.log('\n1️⃣ Verificando autenticación...');
    const email = 'test@example.com'; // ⚠️ CAMBIAR POR TU EMAIL REAL
    const password = 'password123'; // ⚠️ CAMBIAR POR TU PASSWORD REAL
    
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password
    });
    
    if (authError) {
      console.error('❌ Error en login:', authError.message);
      console.log('\n🔧 SOLUCIONES POSIBLES:');
      console.log('- Verificar que el email y password sean correctos');
      console.log('- Verificar que el usuario esté registrado en Supabase');
      console.log('- Verificar configuración de Auth en Supabase');
      return;
    }
    
    console.log('✅ Usuario autenticado:', authData.user.email);
    const userId = authData.user.id;
    
    // 2. Verificar estructura de tablas
    console.log('\n2️⃣ Verificando estructura de tablas...');
    
    const tables = [
      'user_favorites',
      'user_watchlist', 
      'user_watched_movies',
      'user_custom_lists'
    ];
    
    for (const table of tables) {
      try {
        const { data, error } = await supabase
          .from(table)
          .select('*')
          .limit(1);
        
        if (error) {
          console.error(`❌ Error accediendo a ${table}:`, error.message);
          if (error.message.includes('permission denied')) {
            console.log(`   🔧 SOLUCIÓN: Verificar permisos RLS para ${table}`);
          }
        } else {
          console.log(`✅ Tabla ${table} accesible`);
        }
      } catch (err) {
        console.error(`❌ Error con tabla ${table}:`, err.message);
      }
    }
    
    // 3. Obtener datos actuales del usuario
    console.log('\n3️⃣ Obteniendo datos actuales del usuario...');
    
    const [favoritesResult, watchlistResult, watchedResult, listsResult] = await Promise.all([
      supabase.from('user_favorites').select('*').eq('user_id', userId),
      supabase.from('user_watchlist').select('*').eq('user_id', userId),
      supabase.from('user_watched_movies').select('*').eq('user_id', userId),
      supabase.from('user_custom_lists').select('*').eq('user_id', userId)
    ]);
    
    console.log('📊 DATOS ACTUALES EN SUPABASE:');
    console.log(`- Favoritos: ${favoritesResult.data?.length || 0}`);
    console.log(`- Watchlist: ${watchlistResult.data?.length || 0}`);
    console.log(`- Películas vistas: ${watchedResult.data?.length || 0}`);
    console.log(`- Listas personalizadas: ${listsResult.data?.length || 0}`);
    
    // 4. Mostrar detalles de cada categoría
    if (favoritesResult.data && favoritesResult.data.length > 0) {
      console.log('\n📽️ FAVORITOS DETALLADOS:');
      favoritesResult.data.forEach((fav, index) => {
        console.log(`   ${index + 1}. ${fav.title} (ID: ${fav.movie_id}) - Agregado: ${new Date(fav.added_at).toLocaleDateString()}`);
      });
    } else {
      console.log('\n📽️ FAVORITOS: Ninguno encontrado');
    }
    
    if (watchlistResult.data && watchlistResult.data.length > 0) {
      console.log('\n📋 WATCHLIST DETALLADA:');
      watchlistResult.data.forEach((item, index) => {
        console.log(`   ${index + 1}. ${item.title} (ID: ${item.movie_id}) - Prioridad: ${item.priority || 'normal'}`);
      });
    } else {
      console.log('\n📋 WATCHLIST: Ninguna encontrada');
    }
    
    if (watchedResult.data && watchedResult.data.length > 0) {
      console.log('\n✅ PELÍCULAS VISTAS DETALLADAS:');
      watchedResult.data.forEach((movie, index) => {
        console.log(`   ${index + 1}. ${movie.title} (ID: ${movie.movie_id}) - Rating: ${movie.rating || 'N/A'} - Visto: ${new Date(movie.watched_at).toLocaleDateString()}`);
      });
    } else {
      console.log('\n✅ PELÍCULAS VISTAS: Ninguna encontrada');
    }
    
    if (listsResult.data && listsResult.data.length > 0) {
      console.log('\n📝 LISTAS PERSONALIZADAS DETALLADAS:');
      listsResult.data.forEach((list, index) => {
        console.log(`   ${index + 1}. ${list.name} - Descripción: ${list.description || 'Sin descripción'}`);
      });
    } else {
      console.log('\n📝 LISTAS PERSONALIZADAS: Ninguna encontrada');
    }
    
    // 5. Verificar timestamps y patrones
    console.log('\n5️⃣ Analizando patrones de datos...');
    
    const allData = [
      ...(favoritesResult.data || []).map(item => ({ ...item, type: 'favorite' })),
      ...(watchlistResult.data || []).map(item => ({ ...item, type: 'watchlist' })),
      ...(watchedResult.data || []).map(item => ({ ...item, type: 'watched' })),
      ...(listsResult.data || []).map(item => ({ ...item, type: 'list' }))
    ];
    
    if (allData.length > 0) {
      // Ordenar por fecha de creación/agregado
      const sortedData = allData.sort((a, b) => {
        const dateA = new Date(a.added_at || a.watched_at || a.created_at || 0);
        const dateB = new Date(b.added_at || b.watched_at || b.created_at || 0);
        return dateB - dateA;
      });
      
      console.log('\n📅 ACTIVIDAD RECIENTE (últimos 5 elementos):');
      sortedData.slice(0, 5).forEach((item, index) => {
        const date = new Date(item.added_at || item.watched_at || item.created_at);
        console.log(`   ${index + 1}. [${item.type.toUpperCase()}] ${item.title || item.name} - ${date.toLocaleString()}`);
      });
      
      // Detectar posibles duplicados
      const movieIds = allData.filter(item => item.movie_id).map(item => item.movie_id);
      const duplicates = movieIds.filter((id, index) => movieIds.indexOf(id) !== index);
      
      if (duplicates.length > 0) {
        console.log('\n⚠️  POSIBLES DUPLICADOS DETECTADOS:');
        [...new Set(duplicates)].forEach(movieId => {
          const items = allData.filter(item => item.movie_id === movieId);
          console.log(`   Movie ID ${movieId}: ${items.map(item => `${item.type}(${item.title})`).join(', ')}`);
        });
      } else {
        console.log('\n✅ No se detectaron duplicados');
      }
    }
    
    // 6. Probar operaciones básicas
    console.log('\n6️⃣ Probando operaciones básicas...');
    
    // Test de inserción
    const testMovie = {
      user_id: userId,
      movie_id: 999999, // ID único para test
      title: 'Test Movie - Debug',
      poster_path: '/test.jpg',
      release_date: '2024-01-01',
      vote_average: 7.5,
      added_at: new Date().toISOString()
    };
    
    console.log('   Probando inserción en favoritos...');
    const { data: insertResult, error: insertError } = await supabase
      .from('user_favorites')
      .insert(testMovie)
      .select()
      .single();
    
    if (insertError) {
      console.error('   ❌ Error en inserción:', insertError.message);
      if (insertError.message.includes('permission denied')) {
        console.log('   🔧 PROBLEMA: Permisos RLS no configurados correctamente');
      }
    } else {
      console.log('   ✅ Inserción exitosa');
      
      // Test de actualización
      console.log('   Probando actualización...');
      const { error: updateError } = await supabase
        .from('user_favorites')
        .update({ vote_average: 8.0 })
        .eq('id', insertResult.id);
      
      if (updateError) {
        console.error('   ❌ Error en actualización:', updateError.message);
      } else {
        console.log('   ✅ Actualización exitosa');
      }
      
      // Test de eliminación
      console.log('   Probando eliminación...');
      const { error: deleteError } = await supabase
        .from('user_favorites')
        .delete()
        .eq('id', insertResult.id);
      
      if (deleteError) {
        console.error('   ❌ Error en eliminación:', deleteError.message);
      } else {
        console.log('   ✅ Eliminación exitosa');
      }
    }
    
    // 7. Verificar conectividad y estado de la app
    console.log('\n7️⃣ Verificando conectividad...');
    
    try {
      const response = await fetch('http://localhost:3000');
      if (response.ok) {
        console.log('✅ Aplicación Flutter accesible en http://localhost:3000');
      } else {
        console.log('⚠️  Aplicación Flutter responde pero con errores');
      }
    } catch (error) {
      console.log('❌ Aplicación Flutter no accesible:', error.message);
    }
    
    // 8. Resumen y recomendaciones
    console.log('\n8️⃣ RESUMEN Y DIAGNÓSTICO:');
    
    const totalItems = (favoritesResult.data?.length || 0) + 
                      (watchlistResult.data?.length || 0) + 
                      (watchedResult.data?.length || 0) + 
                      (listsResult.data?.length || 0);
    
    if (totalItems === 0) {
      console.log('🔴 PROBLEMA CRÍTICO: No hay datos en Supabase');
      console.log('\n🔧 POSIBLES CAUSAS:');
      console.log('- Los datos nunca se sincronizaron desde Flutter');
      console.log('- Problema con AuthSyncListener no funcionando');
      console.log('- Usuario diferente al que usa en Flutter');
      console.log('- Repositorios híbridos no están guardando en Supabase');
    } else {
      console.log(`🟡 DATOS ENCONTRADOS: ${totalItems} elementos en total`);
      console.log('\n🔧 SI LA UI NO MUESTRA ESTOS DATOS:');
      console.log('- Problema con providers no actualizando la UI');
      console.log('- Datos locales diferentes a los remotos');
      console.log('- AuthSyncListener no descargando datos al login');
      console.log('- Repositorios híbridos priorizando datos locales incorrectos');
    }
    
    console.log('\n📋 PRÓXIMOS PASOS RECOMENDADOS:');
    console.log('1. Verificar que el email/password usado aquí sea el mismo que en Flutter');
    console.log('2. En Flutter, hacer logout y login para forzar sincronización');
    console.log('3. Verificar logs de Flutter para errores de sincronización');
    console.log('4. Probar agregar un favorito en Flutter y verificar si aparece aquí');
    console.log('5. Verificar que los providers estén actualizando la UI correctamente');
    
    console.log('\n🎉 Debug de repositorios híbridos completado!');
    
  } catch (error) {
    console.error('❌ Error en debug:', error.message);
    console.log('\n🔧 SOLUCIONES GENERALES:');
    console.log('- Verificar conexión a internet');
    console.log('- Verificar credenciales de Supabase');
    console.log('- Verificar que las tablas existan en Supabase');
    console.log('- Verificar permisos RLS en Supabase');
  }
}

// Ejecutar debug
debugHybridRepositories()
  .then(() => {
    console.log('\n✅ Debug completado');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Error fatal:', error);
    process.exit(1);
  });

// Instrucciones
console.log('\n📝 INSTRUCCIONES PARA DEBUG:');
console.log('1. Actualiza el email y password con tus credenciales reales');
console.log('2. Ejecuta: node scripts/debug_hybrid_repositories.js');
console.log('3. Compara los datos mostrados aquí con lo que ves en Flutter');
console.log('4. Sigue las recomendaciones del resumen final');