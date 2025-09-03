/**
 * Script para probar la sincronización en la aplicación Flutter
 * Simula el flujo completo de login y verificación de datos
 */

const { createClient } = require('@supabase/supabase-js');

// Configuración de Supabase (credenciales reales del proyecto)
const supabaseUrl = 'https://fyzujpifkzftweynrudh.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTkxOTgsImV4cCI6MjA3MDkzNTE5OH0.-wnFtwyfKuasSJ9GDvhOgKLgfz-clpqnMF1u-lC8sBg';

// Crear cliente de Supabase
const supabase = createClient(supabaseUrl, supabaseKey);

async function testFlutterSync() {
  console.log('🧪 PROBANDO SINCRONIZACIÓN DE FLUTTER');
  console.log('═'.repeat(50));
  
  try {
    // 1. Verificar conexión
    console.log('\n🔗 Verificando conexión a Supabase...');
    const { data: tables, error: tablesError } = await supabase
      .from('user_favorites')
      .select('count', { count: 'exact', head: true });
    
    if (tablesError) {
      console.log('❌ Error de conexión:', tablesError.message);
      return;
    }
    console.log('✅ Conexión exitosa');
    
    // 2. Crear usuario de prueba
    const testEmail = `flutter-test-${Date.now()}@peliculas.com`;
    const testPassword = 'TestPassword123!';
    
    console.log('\n👤 Creando usuario de prueba...');
    console.log('📧 Email:', testEmail);
    
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email: testEmail,
      password: testPassword
    });
    
    if (authError) {
      console.log('❌ Error en registro:', authError.message);
      return;
    }
    
    console.log('✅ Usuario creado exitosamente');
    console.log('🆔 User ID:', authData.user?.id);
    
    // 3. Simular datos que Flutter enviaría
    const testMovieData = {
      user_id: authData.user?.id,
      movie_id: 12345,
      movie_title: 'Película de Prueba Flutter',
      movie_poster_path: '/test-poster.jpg',
      movie_backdrop_path: '/test-backdrop.jpg',
      movie_overview: 'Una película de prueba para verificar sincronización',
      movie_release_date: '2024-01-01',
      movie_vote_average: 8.5,
      is_deleted: false
    };
    
    console.log('\n⬆️ Insertando datos de prueba...');
    const { data: insertData, error: insertError } = await supabase
      .from('user_favorites')
      .insert([testMovieData])
      .select();
    
    if (insertError) {
      console.log('❌ Error en inserción:', insertError.message);
      console.log('💡 Detalles:', insertError);
      return;
    }
    
    console.log('✅ Datos insertados exitosamente');
    console.log('📊 Datos:', insertData);
    
    // 4. Verificar que los datos se pueden leer
    console.log('\n📖 Verificando lectura de datos...');
    const { data: readData, error: readError } = await supabase
      .from('user_favorites')
      .select('*')
      .eq('user_id', authData.user?.id);
    
    if (readError) {
      console.log('❌ Error en lectura:', readError.message);
      return;
    }
    
    console.log('✅ Datos leídos exitosamente');
    console.log('📊 Cantidad de favoritos:', readData?.length || 0);
    
    // 5. Limpiar datos de prueba
    console.log('\n🧹 Limpiando datos de prueba...');
    await supabase
      .from('user_favorites')
      .delete()
      .eq('user_id', authData.user?.id);
    
    console.log('✅ Datos limpiados');
    
    // 6. Resumen
    console.log('\n📊 RESUMEN DE PRUEBA');
    console.log('═'.repeat(30));
    console.log('🎉 ¡SINCRONIZACIÓN DE FLUTTER FUNCIONANDO!');
    console.log('✅ Registro: OK');
    console.log('✅ Inserción: OK');
    console.log('✅ Lectura: OK');
    console.log('\n💡 Si la app no sincroniza, verifica:');
    console.log('   1. Configuración de Supabase en Flutter');
    console.log('   2. Llamadas a syncService.onUserAuthenticated()');
    console.log('   3. Implementación de HybridRepositories');
    console.log('   4. Políticas RLS en Supabase');
    
  } catch (error) {
    console.log('❌ Error inesperado:', error.message);
    console.log('🔍 Stack trace:', error.stack);
  }
}

// Ejecutar prueba
testFlutterSync().catch(console.error);