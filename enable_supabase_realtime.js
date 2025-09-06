const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://fyzujpifkzftweynrudh.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTM1OTE5OCwiZXhwIjoyMDcwOTM1MTk4fQ.O5echdaf1eCKbgG7vaqaRg8q3ew9kuScvl9nVUBJeyM';

const supabase = createClient(supabaseUrl, supabaseKey);

async function enableRealtimeForFavorites() {
  console.log('🔧 Habilitando real-time para user_favorites...');
  
  try {
    // Intentar verificar si la tabla ya está configurada
    const { data: existingConfig, error: checkError } = await supabase
      .from('pg_publication_tables')
      .select('*')
      .eq('pubname', 'supabase_realtime');
    
    if (!checkError) {
      console.log('📋 Configuración actual:', existingConfig);
      
      if (existingConfig && existingConfig.length > 0) {
        const hasUserFavorites = existingConfig.some(config => config.tablename === 'user_favorites');
        if (hasUserFavorites) {
          console.log('✅ user_favorites ya está en la publicación supabase_realtime');
          return;
        }
      }
    }
    
    console.log('ℹ️ Las queries SQL deben ejecutarse manualmente en el dashboard de Supabase:');
    console.log('🔗 Ve a: https://supabase.com/dashboard/project/fyzujpifkzftweynrudh/sql');
    console.log('');
    console.log('📋 Ejecuta estas queries una por una:');
    console.log('');
    console.log('-- 1. Configurar replica identity');
    console.log('ALTER TABLE public.user_favorites REPLICA IDENTITY FULL;');
    console.log('');
    console.log('-- 2. Crear/actualizar publicación');
    console.log('DROP PUBLICATION IF EXISTS supabase_realtime;');
    console.log('CREATE PUBLICATION supabase_realtime FOR TABLE user_favorites;');
    console.log('');
    console.log('-- 3. Verificar configuración');
    console.log('SELECT schemaname, tablename, pubname FROM pg_publication_tables WHERE pubname = \'supabase_realtime\';');
    console.log('');
    console.log('🎯 Después de ejecutar estas queries, reinicia la aplicación Flutter para activar los listeners de real-time');
    
  } catch (error) {
    console.error('❌ Error general:', error);
  }
}

enableRealtimeForFavorites();