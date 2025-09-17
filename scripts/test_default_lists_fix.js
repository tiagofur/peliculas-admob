const { createClient } = require('@supabase/supabase-js');

// Configuración de Supabase (usar las mismas credenciales del proyecto)
const supabaseUrl = 'https://fyzujpifkzftweynrudh.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTM1OTE5OCwiZXhwIjoyMDcwOTM1MTk4fQ.O5echdaf1eCKbgG7vaqaRg8q3ew9kuScvl9nVUBJeyM';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Tipos de listas predeterminadas esperadas
const expectedDefaultTypes = [
  'favorites',
  'watchlist', 
  'watched',
  'action_adventure',
  'comedy',
  'drama',
  'horror_thriller',
  'classics'
];

async function testDefaultListsLogic() {
  console.log('🧪 Iniciando prueba de lógica de listas predeterminadas...');
  
  try {
    // 1. Buscar usuario de prueba
    const testEmail = 'tiagofur@gmail.com';
    const { data: users, error: userError } = await supabase.auth.admin.listUsers();
    
    if (userError) {
      console.error('❌ Error obteniendo usuarios:', userError);
      return;
    }
    
    const testUser = users.users.find(user => user.email === testEmail);
    if (!testUser) {
      console.log(`⚠️ Usuario ${testEmail} no encontrado`);
      return;
    }
    
    console.log(`✅ Usuario encontrado: ${testUser.email} (ID: ${testUser.id})`);
    
    // 2. Verificar listas actuales del usuario
    const { data: currentLists, error: listsError } = await supabase
      .from('user_lists')
      .select('*')
      .eq('user_id', testUser.id)
      .eq('is_default', true);
    
    if (listsError) {
      console.error('❌ Error obteniendo listas:', listsError);
      return;
    }
    
    console.log(`📋 Listas predeterminadas actuales: ${currentLists.length}`);
    
    // 3. Verificar que cada tipo de lista predeterminada existe solo una vez
    const defaultTypeCount = {};
    const duplicates = [];
    
    currentLists.forEach(list => {
      const type = list.default_type;
      if (type) {
        if (defaultTypeCount[type]) {
          defaultTypeCount[type]++;
          duplicates.push({ type, name: list.name, id: list.id });
        } else {
          defaultTypeCount[type] = 1;
        }
      }
    });
    
    // 4. Mostrar resultados
    console.log('\n📊 Análisis de listas predeterminadas:');
    expectedDefaultTypes.forEach(type => {
      const count = defaultTypeCount[type] || 0;
      const status = count === 1 ? '✅' : count === 0 ? '⚠️' : '❌';
      console.log(`${status} ${type}: ${count} lista(s)`);
    });
    
    if (duplicates.length > 0) {
      console.log('\n❌ Duplicados encontrados:');
      duplicates.forEach(dup => {
        console.log(`  - ${dup.type}: ${dup.name} (ID: ${dup.id})`);
      });
    } else {
      console.log('\n✅ No se encontraron duplicados');
    }
    
    // 5. Verificar listas faltantes
    const missingTypes = expectedDefaultTypes.filter(type => !defaultTypeCount[type]);
    if (missingTypes.length > 0) {
      console.log('\n⚠️ Tipos de lista faltantes:');
      missingTypes.forEach(type => console.log(`  - ${type}`));
    } else {
      console.log('\n✅ Todos los tipos de lista predeterminada están presentes');
    }
    
    // 6. Resumen final
    const totalExpected = expectedDefaultTypes.length;
    const totalFound = Object.keys(defaultTypeCount).length;
    const totalDuplicates = duplicates.length;
    
    console.log('\n📈 Resumen:');
    console.log(`  - Tipos esperados: ${totalExpected}`);
    console.log(`  - Tipos encontrados: ${totalFound}`);
    console.log(`  - Duplicados: ${totalDuplicates}`);
    console.log(`  - Estado: ${totalDuplicates === 0 && totalFound === totalExpected ? '✅ CORRECTO' : '❌ NECESITA CORRECCIÓN'}`);
    
  } catch (error) {
    console.error('❌ Error en la prueba:', error);
  }
}

// Ejecutar la prueba
testDefaultListsLogic().then(() => {
  console.log('\n🏁 Prueba completada');
}).catch(error => {
  console.error('💥 Error fatal:', error);
});