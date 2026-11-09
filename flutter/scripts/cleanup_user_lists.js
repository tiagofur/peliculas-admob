const { createClient } = require('@supabase/supabase-js');

// Configuración de Supabase
const supabaseUrl = 'https://fyzujpifkzftweynrudh.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTM1OTE5OCwiZXhwIjoyMDcwOTM1MTk4fQ.O5echdaf1eCKbgG7vaqaRg8q3ew9kuScvl9nVUBJeyM';

// Crear cliente de Supabase con service role
const supabase = createClient(supabaseUrl, supabaseServiceKey);

/**
 * Elimina todas las listas de un usuario específico
 * @param {string} userEmail - Email del usuario
 */
async function deleteAllUserLists(userEmail) {
  try {
    console.log(`🔍 Buscando usuario con email: ${userEmail}`);
    
    // Primero, obtener el ID del usuario por su email
    const { data: userData, error: userError } = await supabase.auth.admin.listUsers();
    
    if (userError) {
      throw new Error(`Error obteniendo usuarios: ${userError.message}`);
    }
    
    const user = userData.users.find(u => u.email === userEmail);
    
    if (!user) {
      console.log(`❌ Usuario con email ${userEmail} no encontrado`);
      return;
    }
    
    const userId = user.id;
    console.log(`✅ Usuario encontrado: ${userEmail} (ID: ${userId})`);
    
    // Obtener todas las listas del usuario
    const { data: lists, error: listsError } = await supabase
      .from('user_lists')
      .select('id, name, is_default, default_type')
      .eq('user_id', userId);
    
    if (listsError) {
      throw new Error(`Error obteniendo listas: ${listsError.message}`);
    }
    
    if (!lists || lists.length === 0) {
      console.log(`ℹ️ No se encontraron listas para el usuario ${userEmail}`);
      return;
    }
    
    console.log(`📋 Encontradas ${lists.length} listas para eliminar:`);
    lists.forEach((list, index) => {
      console.log(`  ${index + 1}. ${list.name} (ID: ${list.id}) - Default: ${list.is_default} - Type: ${list.default_type || 'N/A'}`);
    });
    
    // Confirmar eliminación
    console.log(`\n⚠️ ¿Estás seguro de que quieres eliminar TODAS las ${lists.length} listas del usuario ${userEmail}?`);
    console.log('Esta acción NO se puede deshacer.');
    
    // En un entorno de producción, aquí podrías agregar una confirmación interactiva
    // Por ahora, procedemos directamente
    
    const listIds = lists.map(list => list.id);
    
    // Primero eliminar todos los elementos de las listas
    console.log('🗑️ Eliminando elementos de las listas...');
    const { error: itemsError } = await supabase
      .from('user_list_items')
      .delete()
      .in('list_id', listIds);
    
    if (itemsError) {
      throw new Error(`Error eliminando elementos de listas: ${itemsError.message}`);
    }
    
    console.log('✅ Elementos de listas eliminados');
    
    // Luego eliminar las listas
    console.log('🗑️ Eliminando listas...');
    const { error: deleteError } = await supabase
      .from('user_lists')
      .delete()
      .eq('user_id', userId);
    
    if (deleteError) {
      throw new Error(`Error eliminando listas: ${deleteError.message}`);
    }
    
    console.log(`✅ Todas las ${lists.length} listas del usuario ${userEmail} han sido eliminadas exitosamente`);
    
  } catch (error) {
    console.error('❌ Error durante la eliminación:', error.message);
    throw error;
  }
}

/**
 * Función principal
 */
async function main() {
  const userEmail = 'tiagofur@gmail.com';
  
  try {
    await deleteAllUserLists(userEmail);
    console.log('\n🎉 Proceso de limpieza completado exitosamente');
  } catch (error) {
    console.error('\n💥 Error en el proceso de limpieza:', error.message);
    process.exit(1);
  }
}

// Ejecutar solo si este archivo es ejecutado directamente
if (require.main === module) {
  main();
}

module.exports = { deleteAllUserLists };