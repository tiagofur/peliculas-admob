/**
 * Script para probar la sincronización entre dispositivos
 * Verifica que los datos se sincronicen correctamente después del login
 */

const { createClient } = require('@supabase/supabase-js');

// Configuración de Supabase (usar las variables de entorno reales)
const supabaseUrl = process.env.SUPABASE_URL || 'https://your-project.supabase.co';
const supabaseKey = process.env.SUPABASE_ANON_KEY || 'your-anon-key';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testCrossDeviceSync() {
  console.log('🔄 PROBANDO SINCRONIZACIÓN ENTRE DISPOSITIVOS\n');
  
  try {
    // Datos de prueba
    const testEmail = 'test.sync@example.com';
    const testPassword = 'TestPassword123!';
    
    console.log('1️⃣ Simulando login en dispositivo 1...');
    
    // Login
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: testEmail,
      password: testPassword
    });
    
    if (authError) {
      console.log('❌ Error de autenticación:', authError.message);
      console.log('ℹ️  Nota: Asegúrate de que el usuario existe en Supabase');
      return;
    }
    
    console.log('✅ Login exitoso para:', authData.user.email);
    const userId = authData.user.id;
    
    // Agregar datos de prueba
    console.log('\n2️⃣ Agregando datos de prueba...');
    
    // Agregar película favorita
    const favoriteMovie = {
      user_id: userId,
      movie_id: 12345,
      title: 'Película de Prueba Sync',
      poster_path: '/test-poster.jpg',
      added_at: new Date().toISOString()
    };
    
    const { error: favError } = await supabase
      .from('user_favorites')
      .upsert(favoriteMovie);
    
    if (favError) {
      console.log('❌ Error agregando favorito:', favError.message);
    } else {
      console.log('✅ Película favorita agregada');
    }
    
    // Agregar película vista
    const watchedMovie = {
      user_id: userId,
      movie_id: 67890,
      title: 'Película Vista Sync',
      poster_path: '/test-watched.jpg',
      watched_at: new Date().toISOString()
    };
    
    const { error: watchedError } = await supabase
      .from('user_watched_movies')
      .upsert(watchedMovie);
    
    if (watchedError) {
      console.log('❌ Error agregando película vista:', watchedError.message);
    } else {
      console.log('✅ Película vista agregada');
    }
    
    // Agregar película a watchlist
    const watchlistMovie = {
      user_id: userId,
      movie_id: 11111,
      title: 'Película Watchlist Sync',
      poster_path: '/test-watchlist.jpg',
      added_at: new Date().toISOString()
    };
    
    const { error: watchlistError } = await supabase
      .from('user_watchlist')
      .upsert(watchlistMovie);
    
    if (watchlistError) {
      console.log('❌ Error agregando a watchlist:', watchlistError.message);
    } else {
      console.log('✅ Película agregada a watchlist');
    }
    
    console.log('\n3️⃣ Verificando datos en Supabase...');
    
    // Verificar favoritos
    const { data: favorites, error: favQueryError } = await supabase
      .from('user_favorites')
      .select('*')
      .eq('user_id', userId);
    
    console.log(`📊 Favoritos en Supabase: ${favorites?.length || 0}`);
    
    // Verificar películas vistas
    const { data: watched, error: watchedQueryError } = await supabase
      .from('user_watched_movies')
      .select('*')
      .eq('user_id', userId);
    
    console.log(`📊 Películas vistas en Supabase: ${watched?.length || 0}`);
    
    // Verificar watchlist
    const { data: watchlist, error: watchlistQueryError } = await supabase
      .from('user_watchlist')
      .select('*')
      .eq('user_id', userId);
    
    console.log(`📊 Películas en watchlist: ${watchlist?.length || 0}`);
    
    console.log('\n✅ PRUEBA COMPLETADA');
    console.log('\n📱 INSTRUCCIONES PARA PRUEBA MANUAL:');
    console.log('1. Abre la aplicación en el navegador (http://localhost:3000)');
    console.log('2. Inicia sesión con:', testEmail);
    console.log('3. Verifica que aparezcan los datos agregados');
    console.log('4. Abre la aplicación en otro dispositivo/navegador');
    console.log('5. Inicia sesión con la misma cuenta');
    console.log('6. Verifica que los datos se sincronicen automáticamente');
    
  } catch (error) {
    console.error('❌ Error en la prueba:', error);
  }
}

// Función para limpiar datos de prueba
async function cleanupTestData() {
  console.log('🧹 LIMPIANDO DATOS DE PRUEBA...');
  
  try {
    const testEmail = 'test.sync@example.com';
    const testPassword = 'TestPassword123!';
    
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: testEmail,
      password: testPassword
    });
    
    if (authError) {
      console.log('❌ No se pudo autenticar para limpiar datos');
      return;
    }
    
    const userId = authData.user.id;
    
    // Limpiar favoritos
    await supabase.from('user_favorites').delete().eq('user_id', userId);
    
    // Limpiar películas vistas
    await supabase.from('user_watched_movies').delete().eq('user_id', userId);
    
    // Limpiar watchlist
    await supabase.from('user_watchlist').delete().eq('user_id', userId);
    
    console.log('✅ Datos de prueba limpiados');
    
  } catch (error) {
    console.error('❌ Error limpiando datos:', error);
  }
}

// Ejecutar según el argumento
const command = process.argv[2];

if (command === 'cleanup') {
  cleanupTestData();
} else {
  testCrossDeviceSync();
}