// SCRIPT PARA LIMPIAR CACHE - Ejecutar en Console (F12)
// Este script limpia todo el cache relacionado con perfiles

console.log("🧹 LIMPIEZA DE CACHE DEL PERFIL");
console.log("=".repeat(80));

async function limpiarCachePerfil() {
  let totalLimpiado = 0;

  try {
    // 1. Limpiar localStorage
    console.log("\n📦 1. Limpiando localStorage...");
    const lsKeys = Object.keys(localStorage);
    let lsCount = 0;

    lsKeys.forEach((key) => {
      if (
        key.toLowerCase().includes("profile") ||
        key.toLowerCase().includes("avatar") ||
        key.toLowerCase().includes("user")
      ) {
        console.log(`  🗑️ Eliminando: ${key}`);
        localStorage.removeItem(key);
        lsCount++;
      }
    });

    console.log(`  ✅ ${lsCount} elementos eliminados de localStorage`);
    totalLimpiado += lsCount;

    // 2. Limpiar sessionStorage
    console.log("\n📦 2. Limpiando sessionStorage...");
    const ssKeys = Object.keys(sessionStorage);
    let ssCount = 0;

    ssKeys.forEach((key) => {
      if (
        key.toLowerCase().includes("profile") ||
        key.toLowerCase().includes("avatar") ||
        key.toLowerCase().includes("user")
      ) {
        console.log(`  🗑️ Eliminando: ${key}`);
        sessionStorage.removeItem(key);
        ssCount++;
      }
    });

    console.log(`  ✅ ${ssCount} elementos eliminados de sessionStorage`);
    totalLimpiado += ssCount;

    // 3. Limpiar Cache Storage
    console.log("\n💾 3. Limpiando Cache Storage...");
    const cacheNames = await caches.keys();
    let cacheCount = 0;

    for (const cacheName of cacheNames) {
      console.log(`  🔍 Revisando cache: ${cacheName}`);
      const cache = await caches.open(cacheName);
      const requests = await cache.keys();

      for (const request of requests) {
        if (
          request.url.includes("profile") ||
          request.url.includes("avatar") ||
          request.url.includes("user_profiles") ||
          request.url.includes("supabase")
        ) {
          console.log(`    🗑️ Eliminando: ${request.url}`);
          await cache.delete(request);
          cacheCount++;
        }
      }
    }

    console.log(`  ✅ ${cacheCount} elementos eliminados de Cache Storage`);
    totalLimpiado += cacheCount;

    // 4. Limpiar IndexedDB (donde cached_network_image guarda imágenes)
    console.log("\n🗄️ 4. Limpiando IndexedDB...");
    const dbs = await indexedDB.databases();
    let idbCount = 0;

    for (const db of dbs) {
      if (
        db.name &&
        (db.name.includes("profile") ||
          db.name.includes("avatar") ||
          db.name.includes("cache") ||
          db.name.includes("image"))
      ) {
        console.log(`  🗑️ Eliminando DB: ${db.name}`);
        try {
          indexedDB.deleteDatabase(db.name);
          idbCount++;
        } catch (err) {
          console.error(`    ❌ Error eliminando ${db.name}:`, err);
        }
      }
    }

    console.log(`  ✅ ${idbCount} bases de datos eliminadas de IndexedDB`);
    totalLimpiado += idbCount;

    // 5. Verificar Supabase y limpiar su cache interno si existe
    console.log("\n🔌 5. Verificando cache de Supabase...");
    const supabase = window.supabaseClient || window._supabase;

    if (supabase) {
      console.log("  ✅ Cliente Supabase encontrado");
      // Supabase no tiene cache interno que necesitemos limpiar manualmente
      console.log("  ℹ️ Supabase no requiere limpieza de cache");
    } else {
      console.log("  ⚠️ Cliente Supabase no encontrado");
    }

    // Resumen
    console.log("\n" + "=".repeat(80));
    console.log("✨ LIMPIEZA COMPLETADA");
    console.log(`\n📊 Total de elementos limpiados: ${totalLimpiado}`);

    console.log("\n📋 SIGUIENTE PASO:");
    console.log("  1. Refresca la página (F5 o Ctrl+R)");
    console.log("  2. Haz login de nuevo");
    console.log("  3. Ve a la página de perfil");
    console.log("  4. Verifica que ahora cargue correctamente");

    console.log("\n💡 SI EL PROBLEMA PERSISTE:");
    console.log("  1. Cierra completamente el navegador");
    console.log(
      "  2. Abre Chrome con: chrome.exe --disable-cache --disable-application-cache"
    );
    console.log("  3. O usa modo incógnito (Ctrl+Shift+N)");

    console.log("\n⚠️ NOTA: Tendrás que volver a hacer login después de esto");
  } catch (err) {
    console.error("❌ Error durante la limpieza:", err);
    console.error(err.stack);
  }
}

// Preguntar confirmación
if (
  confirm(
    "⚠️ Esto eliminará TODO el cache relacionado con perfiles.\n\nTendrás que volver a hacer login.\n\n¿Continuar?"
  )
) {
  limpiarCachePerfil();
} else {
  console.log("❌ Limpieza cancelada por el usuario");
}
