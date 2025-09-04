// Script para diagnosticar errores específicos de sincronización
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://fyzujpifkzftweynrudh.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTkxOTgsImV4cCI6MjA3MDkzNTE5OH0.-wnFtwyfKuasSJ9GDvhOgKLgfz-clpqnMF1u-lC8sBg';

async function testSyncErrors() {
  console.log('🔍 Diagnosticando errores de sincronización...\n');

  try {
    const supabase = createClient(supabaseUrl, supabaseKey);
    console.log('✅ Cliente Supabase creado\n');

    // 1. Verificar existencia de tablas
    console.log('📋 Verificando existencia de tablas...');
    const tables = ['user_favorites', 'user_watchlist', 'user_watched_movies', 'user_lists', 'user_list_items'];
    
    for (const table of tables) {
      try {
        const { data, error } = await supabase
          .from(table)
          .select('*')
          .limit(1);
        
        if (error) {
          console.log(`❌ Error en tabla ${table}: ${error.message}`);
        } else {
          console.log(`✅ Tabla ${table} accesible`);
        }
      } catch (e) {
        console.log(`❌ Excepción en tabla ${table}: ${e.message}`);
      }
    }

    // 2. Verificar columnas específicas en user_favorites
    console.log('\n🔍 Verificando columnas en user_favorites...');
    try {
      const { data, error } = await supabase
        .from('user_favorites')
        .select('id, user_id, movie_id, last_modified_at, is_deleted, created_at')
        .limit(1);
      
      if (error) {
        console.log(`❌ Error verificando columnas: ${error.message}`);
      } else {
        console.log('✅ Todas las columnas necesarias están presentes');
      }
    } catch (e) {
      console.log(`❌ Excepción verificando columnas: ${e.message}`);
    }

    // 3. Probar inserción de datos de prueba
    console.log('\n🧪 Probando inserción de datos de prueba...');
    const testData = {
      user_id: '00000000-0000-0000-0000-000000000000', // UUID de prueba
      movie_id: 999999,
      movie_title: 'Test Movie',
      movie_poster_path: '/test.jpg',
      movie_backdrop_path: '/test_backdrop.jpg',
      movie_overview: 'Test overview',
      movie_release_date: '2024-01-01',
      movie_vote_average: 8.5,
      last_modified_at: new Date().toISOString(),
      is_deleted: false
    };

    try {
      const { data, error } = await supabase
        .from('user_favorites')
        .upsert(testData, { onConflict: 'user_id,movie_id' })
        .select();
      
      if (error) {
        console.log(`❌ Error insertando datos de prueba: ${error.message}`);
        console.log(`   Detalles: ${JSON.stringify(error, null, 2)}`);
      } else {
        console.log('✅ Inserción de datos de prueba exitosa');
        console.log(`   Datos insertados: ${JSON.stringify(data, null, 2)}`);
        
        // Limpiar datos de prueba
        await supabase
          .from('user_favorites')
          .delete()
          .eq('movie_id', 999999);
        console.log('🧹 Datos de prueba eliminados');
      }
    } catch (e) {
      console.log(`❌ Excepción insertando datos: ${e.message}`);
    }

    // 4. Verificar permisos RLS
    console.log('\n🔒 Verificando permisos RLS...');
    try {
      const { data, error } = await supabase
        .from('user_favorites')
        .select('count')
        .limit(1);
      
      if (error) {
        console.log(`❌ Error de permisos RLS: ${error.message}`);
      } else {
        console.log('✅ Permisos RLS funcionando correctamente');
      }
    } catch (e) {
      console.log(`❌ Excepción verificando RLS: ${e.message}`);
    }

  } catch (e) {
    console.log(`❌ Error general: ${e.message}`);
  }
}

testSyncErrors();