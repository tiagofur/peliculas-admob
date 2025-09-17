/**
 * Script de Mantenimiento - Limpieza de Listas Duplicadas
 * 
 * Este script permite:
 * 1. Identificar usuarios con listas duplicadas
 * 2. Limpiar listas duplicadas de un usuario específico
 * 3. Generar reportes de estado
 * 
 * Uso:
 * node scripts/maintenance_cleanup_duplicates.js --help
 * node scripts/maintenance_cleanup_duplicates.js --check-user email@example.com
 * node scripts/maintenance_cleanup_duplicates.js --cleanup-user email@example.com
 * node scripts/maintenance_cleanup_duplicates.js --report-all
 */

const { createClient } = require('@supabase/supabase-js');

// Configuración de Supabase
const supabaseUrl = 'https://fyzujpifkzftweynrudh.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTM1OTE5OCwiZXhwIjoyMDcwOTM1MTk4fQ.O5echdaf1eCKbgG7vaqaRg8q3ew9kuScvl9nVUBJeyM';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Tipos de listas por defecto
const DEFAULT_LIST_TYPES = [
  'favorites',
  'watchlist',
  'watched',
  'to_watch',
  'liked',
  'disliked',
  'custom_1',
  'custom_2'
];

/**
 * Obtiene el ID del usuario por email
 */
async function getUserByEmail(email) {
  const { data, error } = await supabase.auth.admin.listUsers();
  
  if (error) {
    console.error('Error obteniendo usuarios:', error);
    return null;
  }
  
  const user = data.users.find(u => u.email === email);
  return user || null;
}

/**
 * Obtiene todas las listas de un usuario
 */
async function getUserLists(userId) {
  const { data, error } = await supabase
    .from('user_lists')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: true });
  
  if (error) {
    console.error('Error obteniendo listas:', error);
    return [];
  }
  
  return data || [];
}

/**
 * Identifica listas duplicadas
 */
function identifyDuplicates(lists) {
  const duplicates = [];
  const seen = new Map();
  
  lists.forEach(list => {
    if (list.is_default) {
      const key = `${list.default_type}_${list.user_id}`;
      if (seen.has(key)) {
        duplicates.push({
          original: seen.get(key),
          duplicate: list
        });
      } else {
        seen.set(key, list);
      }
    }
  });
  
  return duplicates;
}

/**
 * Elimina listas duplicadas manteniendo la más antigua
 */
async function cleanupDuplicates(userId) {
  const lists = await getUserLists(userId);
  const duplicates = identifyDuplicates(lists);
  
  if (duplicates.length === 0) {
    console.log('✅ No se encontraron listas duplicadas');
    return { cleaned: 0, errors: [] };
  }
  
  console.log(`🔍 Encontradas ${duplicates.length} listas duplicadas`);
  
  const errors = [];
  let cleaned = 0;
  
  for (const { duplicate } of duplicates) {
    try {
      // Primero eliminar los items de la lista
      const { error: itemsError } = await supabase
        .from('list_items')
        .delete()
        .eq('list_id', duplicate.id);
      
      if (itemsError) {
        errors.push(`Error eliminando items de lista ${duplicate.id}: ${itemsError.message}`);
        continue;
      }
      
      // Luego eliminar la lista
      const { error: listError } = await supabase
        .from('user_lists')
        .delete()
        .eq('id', duplicate.id);
      
      if (listError) {
        errors.push(`Error eliminando lista ${duplicate.id}: ${listError.message}`);
        continue;
      }
      
      console.log(`🗑️  Eliminada lista duplicada: ${duplicate.name} (${duplicate.default_type})`);
      cleaned++;
    } catch (error) {
      errors.push(`Error inesperado eliminando lista ${duplicate.id}: ${error.message}`);
    }
  }
  
  return { cleaned, errors };
}

/**
 * Verifica el estado de las listas de un usuario
 */
async function checkUserLists(email) {
  const user = await getUserByEmail(email);
  
  if (!user) {
    console.log(`❌ Usuario no encontrado: ${email}`);
    return;
  }
  
  console.log(`👤 Usuario encontrado: ${user.email} (ID: ${user.id})`);
  
  const lists = await getUserLists(user.id);
  const defaultLists = lists.filter(l => l.is_default);
  const customLists = lists.filter(l => !l.is_default);
  const duplicates = identifyDuplicates(lists);
  
  console.log(`\n📊 Resumen de listas:`);
  console.log(`   Total de listas: ${lists.length}`);
  console.log(`   Listas por defecto: ${defaultLists.length}`);
  console.log(`   Listas personalizadas: ${customLists.length}`);
  console.log(`   Listas duplicadas: ${duplicates.length}`);
  
  if (duplicates.length > 0) {
    console.log(`\n🚨 Listas duplicadas encontradas:`);
    duplicates.forEach(({ original, duplicate }) => {
      console.log(`   - ${duplicate.default_type}: Original (${original.created_at}) vs Duplicado (${duplicate.created_at})`);
    });
  }
  
  // Verificar listas faltantes
  const existingTypes = new Set(defaultLists.map(l => l.default_type));
  const missingTypes = DEFAULT_LIST_TYPES.filter(type => !existingTypes.has(type));
  
  if (missingTypes.length > 0) {
    console.log(`\n⚠️  Tipos de lista faltantes: ${missingTypes.join(', ')}`);
  }
  
  console.log(`\n${duplicates.length > 0 ? '❌' : '✅'} Estado: ${duplicates.length > 0 ? 'Necesita limpieza' : 'OK'}`);
}

/**
 * Genera un reporte de todos los usuarios con problemas
 */
async function generateReport() {
  console.log('📋 Generando reporte de usuarios con listas duplicadas...');
  
  const { data: users, error } = await supabase.auth.admin.listUsers();
  
  if (error) {
    console.error('Error obteniendo usuarios:', error);
    return;
  }
  
  const problemUsers = [];
  
  for (const user of users.users) {
    const lists = await getUserLists(user.id);
    const duplicates = identifyDuplicates(lists);
    
    if (duplicates.length > 0) {
      problemUsers.push({
        email: user.email,
        userId: user.id,
        duplicateCount: duplicates.length,
        totalLists: lists.length
      });
    }
  }
  
  console.log(`\n📊 Reporte completo:`);
  console.log(`   Total de usuarios: ${users.users.length}`);
  console.log(`   Usuarios con problemas: ${problemUsers.length}`);
  
  if (problemUsers.length > 0) {
    console.log(`\n🚨 Usuarios que necesitan limpieza:`);
    problemUsers.forEach(user => {
      console.log(`   - ${user.email}: ${user.duplicateCount} duplicados de ${user.totalLists} listas`);
    });
  }
}

/**
 * Función principal
 */
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args.includes('--help')) {
    console.log(`
🛠️  Script de Mantenimiento - Limpieza de Listas Duplicadas
`);
    console.log('Uso:');
    console.log('  node scripts/maintenance_cleanup_duplicates.js --check-user email@example.com');
    console.log('  node scripts/maintenance_cleanup_duplicates.js --cleanup-user email@example.com');
    console.log('  node scripts/maintenance_cleanup_duplicates.js --report-all');
    console.log('  node scripts/maintenance_cleanup_duplicates.js --help');
    return;
  }
  
  if (args.includes('--check-user')) {
    const emailIndex = args.indexOf('--check-user') + 1;
    const email = args[emailIndex];
    
    if (!email) {
      console.error('❌ Debes proporcionar un email');
      return;
    }
    
    await checkUserLists(email);
  }
  
  else if (args.includes('--cleanup-user')) {
    const emailIndex = args.indexOf('--cleanup-user') + 1;
    const email = args[emailIndex];
    
    if (!email) {
      console.error('❌ Debes proporcionar un email');
      return;
    }
    
    const user = await getUserByEmail(email);
    
    if (!user) {
      console.log(`❌ Usuario no encontrado: ${email}`);
      return;
    }
    
    console.log(`🧹 Iniciando limpieza para: ${user.email}`);
    
    const result = await cleanupDuplicates(user.id);
    
    console.log(`\n✅ Limpieza completada:`);
    console.log(`   Listas eliminadas: ${result.cleaned}`);
    
    if (result.errors.length > 0) {
      console.log(`   Errores: ${result.errors.length}`);
      result.errors.forEach(error => console.log(`   - ${error}`));
    }
  }
  
  else if (args.includes('--report-all')) {
    await generateReport();
  }
  
  else {
    console.error('❌ Comando no reconocido. Usa --help para ver las opciones disponibles.');
  }
}

// Ejecutar el script
if (require.main === module) {
  main().catch(console.error);
}

module.exports = {
  getUserByEmail,
  getUserLists,
  identifyDuplicates,
  cleanupDuplicates,
  checkUserLists,
  generateReport
};