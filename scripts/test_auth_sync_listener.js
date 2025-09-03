/**
 * Script para probar si AuthSyncListener está funcionando correctamente
 * Simula login y verifica si se activa la sincronización automática
 */

const { createClient } = require('@supabase/supabase-js');

// Configuración de Supabase (usar las mismas credenciales del proyecto)
const supabaseUrl = 'https://your-project.supabase.co';
const supabaseKey = 'your-anon-key';

// Crear cliente de Supabase
const supabase = createClient(supabaseUrl, supabaseKey);

async function testAuthSyncListener() {
  console.log('🧪 Iniciando test de AuthSyncListener...');
  
  try {
    // 1. Verificar estado inicial
    console.log('\n1️⃣ Verificando estado inicial...');
    const { data: { user: initialUser } } = await supabase.auth.getUser();
    console.log('Usuario inicial:', initialUser ? 'Autenticado' : 'No autenticado');
    
    // 2. Simular login (usar credenciales reales del usuario)
    console.log('\n2️⃣ Simulando login...');
    const email = 'test@example.com'; // Cambiar por email real
    const password = 'password123'; // Cambiar por password real
    
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password
    });
    
    if (authError) {
      console.error('❌ Error en login:', authError.message);
      return;
    }
    
    console.log('✅ Login exitoso:', authData.user.email);
    
    // 3. Esperar un momento para que se active la sincronización
    console.log('\n3️⃣ Esperando activación de sincronización automática...');
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // 4. Verificar si hay datos sincronizados
    console.log('\n4️⃣ Verificando datos sincronizados...');
    
    // Verificar favoritos
    const { data: favorites, error: favError } = await supabase
      .from('user_favorites')
      .select('*')
      .eq('user_id', authData.user.id);
    
    console.log('Favoritos encontrados:', favorites?.length || 0);
    if (favError) console.error('Error favoritos:', favError.message);
    
    // Verificar watchlist
    const { data: watchlist, error: watchError } = await supabase
      .from('user_watchlist')
      .select('*')
      .eq('user_id', authData.user.id);
    
    console.log('Watchlist encontrada:', watchlist?.length || 0);
    if (watchError) console.error('Error watchlist:', watchError.message);
    
    // Verificar películas vistas
    const { data: watched, error: watchedError } = await supabase
      .from('user_watched_movies')
      .select('*')
      .eq('user_id', authData.user.id);
    
    console.log('Películas vistas:', watched?.length || 0);
    if (watchedError) console.error('Error watched:', watchedError.message);
    
    // Verificar listas personalizadas
    const { data: customLists, error: listsError } = await supabase
      .from('user_custom_lists')
      .select('*')
      .eq('user_id', authData.user.id);
    
    console.log('Listas personalizadas:', customLists?.length || 0);
    if (listsError) console.error('Error listas:', listsError.message);
    
    // 5. Agregar un favorito de prueba para verificar sincronización en tiempo real
    console.log('\n5️⃣ Agregando favorito de prueba...');
    const testMovie = {
      user_id: authData.user.id,
      movie_id: 550, // Fight Club
      title: 'Fight Club',
      poster_path: '/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg',
      release_date: '1999-10-15',
      vote_average: 8.4,
      added_at: new Date().toISOString()
    };
    
    const { data: newFavorite, error: addError } = await supabase
      .from('user_favorites')
      .insert(testMovie)
      .select()
      .single();
    
    if (addError) {
      console.error('❌ Error agregando favorito:', addError.message);
    } else {
      console.log('✅ Favorito agregado:', newFavorite.title);
    }
    
    // 6. Verificar que el favorito se agregó correctamente
    console.log('\n6️⃣ Verificando favorito agregado...');
    const { data: updatedFavorites } = await supabase
      .from('user_favorites')
      .select('*')
      .eq('user_id', authData.user.id);
    
    console.log('Total favoritos después de agregar:', updatedFavorites?.length || 0);
    
    // 7. Limpiar datos de prueba
    console.log('\n7️⃣ Limpiando datos de prueba...');
    if (newFavorite) {
      await supabase
        .from('user_favorites')
        .delete()
        .eq('id', newFavorite.id);
      console.log('✅ Datos de prueba limpiados');
    }
    
    console.log('\n🎉 Test completado exitosamente!');
    console.log('\n📋 RESUMEN:');
    console.log(`- Favoritos: ${favorites?.length || 0}`);
    console.log(`- Watchlist: ${watchlist?.length || 0}`);
    console.log(`- Películas vistas: ${watched?.length || 0}`);
    console.log(`- Listas personalizadas: ${customLists?.length || 0}`);
    
  } catch (error) {
    console.error('❌ Error en test:', error.message);
  }
}

// Ejecutar test
testAuthSyncListener().then(() => {
  console.log('\n✅ Test finalizado');
  process.exit(0);
}).catch(error => {
  console.error('❌ Error fatal:', error);
  process.exit(1);
});

// Instrucciones de uso
console.log('\n📝 INSTRUCCIONES:');
console.log('1. Actualiza las credenciales de Supabase en este archivo');
console.log('2. Actualiza el email y password del usuario de prueba');
console.log('3. Ejecuta: node scripts/test_auth_sync_listener.js');
console.log('4. Observa si la sincronización automática funciona después del login');
console.log('\n⚠️  IMPORTANTE: Este test verifica si AuthSyncListener detecta cambios de auth');
console.log('   Si no hay datos, puede ser que la sincronización automática no esté funcionando');