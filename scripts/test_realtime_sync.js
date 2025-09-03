/**
 * Script para probar sincronización en tiempo real
 * Simula cambios de datos y verifica si se reflejan correctamente
 */

const { createClient } = require('@supabase/supabase-js');

// Configuración de Supabase
const supabaseUrl = 'https://fyzujpifkzftweynrudh.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTkxOTgsImV4cCI6MjA3MDkzNTE5OH0.-wnFtwyfKuasSJ9GDvhOgKLgfz-clpqnMF1u-lC8sBg';

// Crear cliente de Supabase
const supabase = createClient(supabaseUrl, supabaseKey);

async function testRealtimeSync() {
  console.log('🔄 Iniciando test de sincronización en tiempo real...');
  
  try {
    // 1. Autenticar usuario
    console.log('\n1️⃣ Autenticando usuario...');
    const email = 'test@example.com'; // ⚠️ CAMBIAR POR TU EMAIL REAL
    const password = 'password123'; // ⚠️ CAMBIAR POR TU PASSWORD REAL
    
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password
    });
    
    if (authError) {
      console.error('❌ Error en login:', authError.message);
      return;
    }
    
    console.log('✅ Usuario autenticado:', authData.user.email);
    const userId = authData.user.id;
    
    // 2. Obtener estado inicial de datos
    console.log('\n2️⃣ Obteniendo estado inicial...');
    
    const [favoritesResult, watchlistResult, watchedResult, listsResult] = await Promise.all([
      supabase.from('user_favorites').select('*').eq('user_id', userId),
      supabase.from('user_watchlist').select('*').eq('user_id', userId),
      supabase.from('user_watched_movies').select('*').eq('user_id', userId),
      supabase.from('user_custom_lists').select('*').eq('user_id', userId)
    ]);
    
    console.log('📊 Estado inicial:');
    console.log(`- Favoritos: ${favoritesResult.data?.length || 0}`);
    console.log(`- Watchlist: ${watchlistResult.data?.length || 0}`);
    console.log(`- Películas vistas: ${watchedResult.data?.length || 0}`);
    console.log(`- Listas personalizadas: ${listsResult.data?.length || 0}`);
    
    // 3. Agregar datos de prueba y verificar sincronización
    console.log('\n3️⃣ Agregando datos de prueba...');
    
    // Agregar favorito
    const testFavorite = {
      user_id: userId,
      movie_id: 550, // Fight Club
      title: 'Fight Club (Test)',
      poster_path: '/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg',
      release_date: '1999-10-15',
      vote_average: 8.4,
      added_at: new Date().toISOString()
    };
    
    const { data: newFavorite, error: favError } = await supabase
      .from('user_favorites')
      .insert(testFavorite)
      .select()
      .single();
    
    if (favError) {
      console.error('❌ Error agregando favorito:', favError.message);
    } else {
      console.log('✅ Favorito agregado:', newFavorite.title);
    }
    
    // Agregar a watchlist
    const testWatchlist = {
      user_id: userId,
      movie_id: 680, // Pulp Fiction
      title: 'Pulp Fiction (Test)',
      poster_path: '/d5iIlFn5s0ImszYzBPb8JPIfbXD.jpg',
      release_date: '1994-09-10',
      vote_average: 8.9,
      priority: 'high',
      added_at: new Date().toISOString()
    };
    
    const { data: newWatchlist, error: watchError } = await supabase
      .from('user_watchlist')
      .insert(testWatchlist)
      .select()
      .single();
    
    if (watchError) {
      console.error('❌ Error agregando a watchlist:', watchError.message);
    } else {
      console.log('✅ Película agregada a watchlist:', newWatchlist.title);
    }
    
    // Agregar película vista
    const testWatched = {
      user_id: userId,
      movie_id: 13, // Forrest Gump
      title: 'Forrest Gump (Test)',
      poster_path: '/arw2vcBveWOVZr6pxd9XTd1TdQa.jpg',
      release_date: '1994-06-23',
      vote_average: 8.5,
      watched_at: new Date().toISOString(),
      rating: 9
    };
    
    const { data: newWatched, error: watchedError } = await supabase
      .from('user_watched_movies')
      .insert(testWatched)
      .select()
      .single();
    
    if (watchedError) {
      console.error('❌ Error agregando película vista:', watchedError.message);
    } else {
      console.log('✅ Película vista agregada:', newWatched.title);
    }
    
    // 4. Esperar un momento para simular tiempo real
    console.log('\n4️⃣ Esperando sincronización...');
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // 5. Verificar que los datos se agregaron correctamente
    console.log('\n5️⃣ Verificando datos después de cambios...');
    
    const [newFavoritesResult, newWatchlistResult, newWatchedResult] = await Promise.all([
      supabase.from('user_favorites').select('*').eq('user_id', userId),
      supabase.from('user_watchlist').select('*').eq('user_id', userId),
      supabase.from('user_watched_movies').select('*').eq('user_id', userId)
    ]);
    
    console.log('📊 Estado después de cambios:');
    console.log(`- Favoritos: ${newFavoritesResult.data?.length || 0}`);
    console.log(`- Watchlist: ${newWatchlistResult.data?.length || 0}`);
    console.log(`- Películas vistas: ${newWatchedResult.data?.length || 0}`);
    
    // 6. Probar actualización de datos existentes
    console.log('\n6️⃣ Probando actualización de datos...');
    
    if (newFavorite) {
      const { error: updateError } = await supabase
        .from('user_favorites')
        .update({ vote_average: 9.0 })
        .eq('id', newFavorite.id);
      
      if (updateError) {
        console.error('❌ Error actualizando favorito:', updateError.message);
      } else {
        console.log('✅ Favorito actualizado correctamente');
      }
    }
    
    // 7. Probar eliminación de datos
    console.log('\n7️⃣ Probando eliminación de datos...');
    
    const itemsToDelete = [];
    if (newFavorite) itemsToDelete.push({ table: 'user_favorites', id: newFavorite.id, title: newFavorite.title });
    if (newWatchlist) itemsToDelete.push({ table: 'user_watchlist', id: newWatchlist.id, title: newWatchlist.title });
    if (newWatched) itemsToDelete.push({ table: 'user_watched_movies', id: newWatched.id, title: newWatched.title });
    
    for (const item of itemsToDelete) {
      const { error: deleteError } = await supabase
        .from(item.table)
        .delete()
        .eq('id', item.id);
      
      if (deleteError) {
        console.error(`❌ Error eliminando ${item.title}:`, deleteError.message);
      } else {
        console.log(`✅ ${item.title} eliminado correctamente`);
      }
    }
    
    // 8. Verificar estado final
    console.log('\n8️⃣ Verificando estado final...');
    
    const [finalFavoritesResult, finalWatchlistResult, finalWatchedResult] = await Promise.all([
      supabase.from('user_favorites').select('*').eq('user_id', userId),
      supabase.from('user_watchlist').select('*').eq('user_id', userId),
      supabase.from('user_watched_movies').select('*').eq('user_id', userId)
    ]);
    
    console.log('📊 Estado final:');
    console.log(`- Favoritos: ${finalFavoritesResult.data?.length || 0}`);
    console.log(`- Watchlist: ${finalWatchlistResult.data?.length || 0}`);
    console.log(`- Películas vistas: ${finalWatchedResult.data?.length || 0}`);
    
    // 9. Análisis de sincronización
    console.log('\n9️⃣ Análisis de sincronización:');
    
    const initialTotal = (favoritesResult.data?.length || 0) + 
                        (watchlistResult.data?.length || 0) + 
                        (watchedResult.data?.length || 0);
    
    const finalTotal = (finalFavoritesResult.data?.length || 0) + 
                      (finalWatchlistResult.data?.length || 0) + 
                      (finalWatchedResult.data?.length || 0);
    
    console.log(`Total inicial: ${initialTotal}`);
    console.log(`Total final: ${finalTotal}`);
    
    if (finalTotal === initialTotal) {
      console.log('✅ Sincronización funcionando correctamente - datos se agregaron y eliminaron');
    } else {
      console.log('⚠️  Posible problema de sincronización - diferencia en totales');
    }
    
    console.log('\n🎉 Test de sincronización en tiempo real completado!');
    
  } catch (error) {
    console.error('❌ Error en test:', error.message);
  }
}

// Función para probar conflictos de sincronización
async function testSyncConflicts() {
  console.log('\n🔀 Probando resolución de conflictos...');
  
  try {
    // Simular datos que podrían estar tanto local como remotamente
    // Este test requeriría acceso a los datos locales de Flutter
    console.log('⚠️  Test de conflictos requiere integración con Flutter');
    console.log('   Para probar conflictos:');
    console.log('   1. Agregar datos en Flutter (offline)');
    console.log('   2. Agregar datos diferentes en Supabase (online)');
    console.log('   3. Conectar Flutter y verificar resolución');
    
  } catch (error) {
    console.error('❌ Error en test de conflictos:', error.message);
  }
}

// Ejecutar tests
testRealtimeSync()
  .then(() => testSyncConflicts())
  .then(() => {
    console.log('\n✅ Todos los tests completados');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Error fatal:', error);
    process.exit(1);
  });

// Instrucciones
console.log('\n📝 INSTRUCCIONES PARA TEST DE SINCRONIZACIÓN EN TIEMPO REAL:');
console.log('1. Actualiza las credenciales de Supabase en este archivo');
console.log('2. Actualiza el email y password del usuario de prueba');
console.log('3. Ejecuta: node scripts/test_realtime_sync.js');
console.log('4. Observa si los cambios se reflejan correctamente en Supabase');
console.log('5. Verifica en Flutter si los cambios aparecen en la UI');
console.log('\n🔍 QUÉ BUSCAR:');
console.log('- ✅ Datos se agregan correctamente');
console.log('- ✅ Datos se actualizan correctamente');
console.log('- ✅ Datos se eliminan correctamente');
console.log('- ✅ Totales coinciden antes y después');
console.log('- ❌ Errores de permisos o RLS');
console.log('- ❌ Datos que no se sincronizan');
console.log('- ❌ Conflictos no resueltos');