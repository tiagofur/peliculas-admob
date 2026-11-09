// Script para verificar el estado de user_lists en Supabase
const SUPABASE_URL = 'https://fyzujpifkzftweynrudh.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTkxOTgsImV4cCI6MjA3MDkzNTE5OH0.-wnFtwyfKuasSJ9GDvhOgKLgfz-clpqnMF1u-lC8sBg';

async function checkLists() {
    try {
        const response = await fetch(
            `${SUPABASE_URL}/rest/v1/user_lists?select=*&order=created_at.desc`,
            {
                headers: {
                    'apikey': SUPABASE_ANON_KEY,
                    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`
                }
            }
        );

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const lists = await response.json();

        console.log('\n=== DIAGNÓSTICO DE LISTAS ===\n');
        console.log(`Total de listas: ${lists.length}\n`);

        // Agrupar por default_type
        const byType = {};
        const predefinidas = lists.filter(l => l.is_default);
        const personalizadas = lists.filter(l => !l.is_default);

        console.log(`Listas predefinidas: ${predefinidas.length}`);
        console.log(`Listas personalizadas: ${personalizadas.length}\n`);

        // Contar duplicados
        predefinidas.forEach(list => {
            if (!byType[list.default_type]) {
                byType[list.default_type] = [];
            }
            byType[list.default_type].push(list);
        });

        console.log('=== DUPLICADOS POR TIPO ===\n');
        Object.entries(byType).forEach(([type, lists]) => {
            if (lists.length > 1) {
                console.log(`❌ ${type}: ${lists.length} copias (DUPLICADO!)`);
            } else {
                console.log(`✅ ${type}: 1 copia`);
            }
        });

        console.log('\n=== DETALLES DE LISTAS PREDEFINIDAS ===\n');
        predefinidas.forEach(list => {
            const emojiStatus = list.emoji === '📝' ? '❌ GENÉRICO' : '✅';
            const colorStatus = (list.color_hex === '#2196F3' || !list.color_hex) ? '❌ DEFAULT' : '✅';

            console.log(`${list.name}:`);
            console.log(`  Emoji: ${list.emoji} ${emojiStatus}`);
            console.log(`  Color: ${list.color_hex || 'NULL'} ${colorStatus}`);
            console.log(`  Type: ${list.default_type}`);
            console.log(`  Created: ${list.created_at}`);
            console.log('');
        });

        // Verificar índices únicos
        console.log('\n=== VERIFICANDO ÍNDICES ÚNICOS ===\n');
        const indexResponse = await fetch(
            `${SUPABASE_URL}/rest/v1/rpc/check_unique_index`,
            {
                method: 'POST',
                headers: {
                    'apikey': SUPABASE_ANON_KEY,
                    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
                    'Content-Type': 'application/json'
                }
            }
        );

        if (indexResponse.ok) {
            console.log('✅ Índices únicos verificados');
        } else {
            console.log('⚠️  No se pudo verificar índices (esto es normal si no existe la función RPC)');
        }

    } catch (error) {
        console.error('Error:', error.message);
    }
}

checkLists();
