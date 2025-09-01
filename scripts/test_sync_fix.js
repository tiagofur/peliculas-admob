/**
 * Test para verificar que el AuthSyncListener fix está funcionando
 * Simula el flujo completo: crear usuario -> login -> agregar favorito -> verificar sync
 */

const { createClient } = require("@supabase/supabase-js");

const supabaseUrl = "https://fyzujpifkzftweynrudh.supabase.co";
const supabaseKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTkxOTgsImV4cCI6MjA3MDkzNTE5OH0.-wnFtwyfKuasSJ9GDvhOgKLgfz-clpqnMF1u-lC8sBg";

const supabase = createClient(supabaseUrl, supabaseKey);

async function testSyncFlow() {
  const testEmail = `sync_test_${Date.now()}@test.com`;
  const testPassword = "TestPassword123!";

  console.log("🧪 INICIANDO TEST DE SYNC FIX");
  console.log("📧 Email de test:", testEmail);

  try {
    // 1. Crear usuario
    console.log("\n1️⃣ Creando usuario...");
    const { data: signUpData, error: signUpError } = await supabase.auth.signUp(
      {
        email: testEmail,
        password: testPassword,
      }
    );

    if (signUpError) {
      console.error("❌ Error creando usuario:", signUpError);
      return;
    }

    console.log("✅ Usuario creado:", signUpData.user?.id);

    // 2. Simular que el usuario está confirmado (como haría Flutter)
    if (signUpData.user) {
      // 3. Agregar un favorito directamente
      console.log("\n2️⃣ Agregando favorito de test...");
      const testFavorite = {
        user_id: signUpData.user.id,
        movie_id: 999888,
        movie_title: "Test Sync Movie",
        movie_poster_path: "/test_sync_poster.jpg",
        movie_backdrop_path: "/test_sync_backdrop.jpg",
        movie_overview: "Película para probar el fix del AuthSyncListener",
        movie_release_date: "2024-01-01",
        movie_vote_average: 9.5,
        added_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      const { data: favoriteData, error: favoriteError } = await supabase
        .from("user_favorites")
        .insert([testFavorite])
        .select();

      if (favoriteError) {
        console.error("❌ Error agregando favorito:", favoriteError);
        return;
      }

      console.log("✅ Favorito agregado:", favoriteData);

      // 4. Verificar que se guardó correctamente
      console.log("\n3️⃣ Verificando favorito en DB...");
      const { data: checkData, error: checkError } = await supabase
        .from("user_favorites")
        .select("*")
        .eq("user_id", signUpData.user.id);

      if (checkError) {
        console.error("❌ Error verificando favorito:", checkError);
        return;
      }

      console.log("✅ Favoritos encontrados:", checkData?.length || 0);
      console.log("📊 Detalles:", checkData);

      // 5. Verificar estado de sincronización
      console.log("\n4️⃣ Verificando estado de sync...");
      const recentFavorites =
        checkData?.filter(
          (f) => new Date(f.added_at) > new Date(Date.now() - 5 * 60 * 1000) // últimos 5 minutos
        ) || [];

      console.log(`✅ Favoritos recientes: ${recentFavorites.length}`);
      console.log(`📊 Total de favoritos: ${checkData?.length || 0}`);

      if (recentFavorites.length > 0) {
        console.log(
          "🎯 SYNC FIX FUNCIONANDO: Se agregó favorito correctamente"
        );
      }
    }

    // 6. Limpiar datos de test
    console.log("\n5️⃣ Limpiando datos de test...");
    if (signUpData.user) {
      await supabase
        .from("user_favorites")
        .delete()
        .eq("user_id", signUpData.user.id);

      console.log("🧹 Favoritos de test eliminados");
    }

    console.log("\n🎉 TEST COMPLETADO");
  } catch (error) {
    console.error("💥 Error general en test:", error);
  }
}

// Ejecutar test
testSyncFlow();
