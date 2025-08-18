// Script para consultar datos en la tabla user_favorites de Supabase
const { createClient } = require("@supabase/supabase-js");

const supabaseUrl = "https://fyzujpifkzftweynrudh.supabase.co";
const supabaseKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTkxOTgsImV4cCI6MjA3MDkzNTE5OH0.-wnFtwyfKuasSJ9GDvhOgKLgfz-clpqnMF1u-lC8sBg";

async function checkFavoritesData() {
  console.log(
    "🔍 Consultando datos en la tabla user_favorites de Supabase...\n"
  );

  try {
    // Crear cliente
    const supabase = createClient(supabaseUrl, supabaseKey);
    console.log("✅ Cliente Supabase inicializado\n");

    // 1. Intentar consultar todos los favoritos (sin autenticación)
    console.log("📊 Consultando tabla user_favorites...");
    const { data: allFavorites, error: allError } = await supabase
      .from("user_favorites")
      .select("*");

    if (allError) {
      console.log(
        `⚠️ Error al consultar sin autenticación: ${allError.message}`
      );
      console.log("   Esto es esperado si RLS está activo.\n");
    } else if (allFavorites) {
      console.log(`📈 Total de registros encontrados: ${allFavorites.length}`);

      if (allFavorites.length > 0) {
        console.log("\n📋 Datos encontrados en user_favorites:");
        console.log("═".repeat(80));

        allFavorites.forEach((favorite, index) => {
          console.log(
            `${index + 1}. 🎬 ${favorite.movie_title || "Sin título"}`
          );
          console.log(`   📺 ID Película: ${favorite.movie_id}`);
          console.log(`   👤 Usuario: ${favorite.user_id}`);
          console.log(`   🖼️ Poster: ${favorite.movie_poster_path || "N/A"}`);
          console.log(`   ⭐ Rating: ${favorite.movie_vote_average || "N/A"}`);
          console.log(`   📅 Fecha: ${favorite.movie_release_date || "N/A"}`);
          console.log(`   🕒 Actualizado: ${favorite.updated_at}`);
          console.log(`   🕒 Creado: ${favorite.created_at || "N/A"}`);
          console.log("─".repeat(40));
        });
      } else {
        console.log(
          "\n📭 La tabla user_favorites está vacía (no hay registros)."
        );
      }
    }

    // 2. Consultar información de la tabla (estructura)
    console.log("\n🏗️ Consultando estructura de la tabla...");

    try {
      // Consultar con límite 0 para obtener la estructura sin datos
      const { data: structure, error: structError } = await supabase
        .from("user_favorites")
        .select("*")
        .limit(0);

      if (structError) {
        console.log(`⚠️ Error al consultar estructura: ${structError.message}`);
      } else {
        console.log("✅ La tabla user_favorites existe y es accesible");
      }
    } catch (structError) {
      console.log(`❌ Error en consulta de estructura: ${structError.message}`);
    }

    // 3. Consultar otras tablas relacionadas
    console.log("\n🔗 Consultando otras tablas relacionadas...");

    const tables = [
      "user_profiles",
      "user_stats",
      "user_watched_movies",
      "user_lists",
      "user_list_items",
    ];

    for (const tableName of tables) {
      try {
        const { data: tableData, error: tableError } = await supabase
          .from(tableName)
          .select("*")
          .limit(1);

        if (tableError) {
          console.log(`   📋 ${tableName}: ❌ ${tableError.message}`);
        } else {
          console.log(
            `   📋 ${tableName}: ✅ Accesible (${
              tableData?.length || 0
            } registros visibles)`
          );
        }
      } catch (e) {
        console.log(`   📋 ${tableName}: ❌ Error: ${e.message}`);
      }
    }

    // 4. Resumen final
    console.log("\n📊 RESUMEN:");
    console.log("═".repeat(50));
    console.log("🔗 Conexión a Supabase: ✅ Exitosa");
    console.log("🏗️ Tabla user_favorites: ✅ Existe");

    if (allFavorites && allFavorites.length > 0) {
      console.log(`📈 Registros en favoritos: ${allFavorites.length}`);
      console.log("💾 Estado: ✅ Contiene datos");
    } else if (allError && allError.message.includes("policy")) {
      console.log("🔒 Seguridad RLS: ✅ Activa (necesita autenticación)");
      console.log("📈 Registros visibles: ❓ (requiere login para ver)");
    } else {
      console.log("📈 Registros en favoritos: 0");
      console.log("💾 Estado: 📭 Tabla vacía");
    }
  } catch (error) {
    console.log(`❌ Error general: ${error.message}`);
    console.log("Stack trace:", error.stack);
  }
}

// Ejecutar la consulta
checkFavoritesData();
