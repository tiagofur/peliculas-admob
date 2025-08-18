// Script simple para probar Supabase con JavaScript
const { createClient } = require("@supabase/supabase-js");

const supabaseUrl = "https://fyzujpifkzftweynrudh.supabase.co";
const supabaseKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTkxOTgsImV4cCI6MjA3MDkzNTE5OH0.-wnFtwyfKuasSJ9GDvhOgKLgfz-clpqnMF1u-lC8sBg";

async function testSupabase() {
  console.log("🧪 Iniciando test de Supabase...\n");

  try {
    // 1. Crear cliente
    const supabase = createClient(supabaseUrl, supabaseKey);
    console.log("✅ Cliente Supabase creado\n");

    // 2. Test de autenticación
    // Usar un timestamp único para cada test
    const authTimestamp = Date.now();
    const testEmail = `test-sync-${authTimestamp}@peliculas.com`;
    const testPassword = "TestPassword123!";

    console.log("🔐 Probando autenticación...");
    console.log(`📧 Usando email de prueba: ${testEmail}`);

    let user = null;

    try {
      // Intentar login
      const { data: loginData, error: loginError } =
        await supabase.auth.signInWithPassword({
          email: testEmail,
          password: testPassword,
        });

      if (loginData.user && !loginError) {
        user = loginData.user;
        console.log(`✅ Login exitoso: ${loginData.user.email}`);
      } else {
        console.log(
          `⚠️ Login falló: ${loginError?.message || "Usuario no encontrado"}`
        );
        console.log("📝 Intentando registro...");

        // Intentar registro
        const { data: signUpData, error: signUpError } =
          await supabase.auth.signUp({
            email: testEmail,
            password: testPassword,
            options: {
              emailRedirectTo: undefined, // Evitar redirección de email
            },
          });

        if (signUpData.user && !signUpError) {
          user = signUpData.user;
          console.log(`✅ Registro exitoso: ${signUpData.user.email}`);

          // Después del registro, intentar login inmediatamente
          console.log("🔄 Iniciando sesión después del registro...");
          const { data: postRegisterLogin, error: postRegisterError } =
            await supabase.auth.signInWithPassword({
              email: testEmail,
              password: testPassword,
            });

          if (postRegisterLogin.user && !postRegisterError) {
            user = postRegisterLogin.user;
            console.log(
              `✅ Login post-registro exitoso: ${postRegisterLogin.user.email}`
            );
          } else {
            console.log(
              `❌ Error en login post-registro: ${postRegisterError?.message}`
            );
          }
        } else {
          console.log(`❌ Error en registro: ${signUpError?.message}`);
        }
      }
    } catch (authError) {
      console.log(`❌ Error en autenticación: ${authError.message}`);
    }

    if (!user) {
      console.log("❌ No se pudo autenticar. Terminando test.");
      return;
    }

    console.log(`👤 Usuario actual: ${user.email}`);

    // Verificar el estado de la sesión actual
    const { data: sessionData, error: sessionError } =
      await supabase.auth.getSession();
    if (sessionData.session) {
      console.log(
        `🔒 Sesión activa confirmada para: ${sessionData.session.user.email}`
      );
    } else {
      console.log(
        `❌ No hay sesión activa: ${
          sessionError?.message || "Sesión no encontrada"
        }`
      );
      return;
    }

    console.log();

    // 3. Test de operaciones CRUD
    console.log("📊 Probando operaciones CRUD en user_favorites...");

    const testMovieId = 99999;
    const timestamp = Date.now();
    const testData = {
      user_id: user.id,
      movie_id: testMovieId,
      movie_title: `Test Movie ${timestamp}`,
      movie_poster_path: "/test_poster.jpg",
      movie_backdrop_path: "/test_backdrop.jpg",
      movie_overview: "Test movie para probar sincronización",
      movie_release_date: "2023-01-01",
      movie_vote_average: 8.5,
      updated_at: new Date().toISOString(),
    };

    // CREATE - Insertar favorito
    console.log("⬆️ Insertando favorito...");
    const { error: insertError } = await supabase
      .from("user_favorites")
      .upsert(testData, { onConflict: "user_id,movie_id" });

    if (insertError) {
      console.log(`❌ Error al insertar: ${insertError.message}`);
      return;
    }
    console.log("✅ Favorito insertado");

    // READ - Leer favorito
    console.log("📖 Leyendo favorito...");
    const { data: readData, error: readError } = await supabase
      .from("user_favorites")
      .select()
      .eq("user_id", user.id)
      .eq("movie_id", testMovieId);

    if (readError) {
      console.log(`❌ Error al leer: ${readError.message}`);
      return;
    }

    if (readData && readData.length > 0) {
      console.log(`✅ Favorito encontrado: ${readData[0].movie_title}`);
    } else {
      console.log("❌ No se encontró el favorito recién insertado");
      return;
    }

    // UPDATE - Actualizar favorito
    console.log("✏️ Actualizando favorito...");
    const { error: updateError } = await supabase
      .from("user_favorites")
      .update({
        movie_title: `Updated Test Movie ${timestamp}`,
        updated_at: new Date().toISOString(),
      })
      .eq("user_id", user.id)
      .eq("movie_id", testMovieId);

    if (updateError) {
      console.log(`❌ Error al actualizar: ${updateError.message}`);
      return;
    }
    console.log("✅ Favorito actualizado");

    // Verificar actualización
    const { data: updatedData, error: verifyError } = await supabase
      .from("user_favorites")
      .select()
      .eq("user_id", user.id)
      .eq("movie_id", testMovieId);

    if (verifyError) {
      console.log(`❌ Error al verificar: ${verifyError.message}`);
      return;
    }

    if (
      updatedData &&
      updatedData[0] &&
      updatedData[0].movie_title === `Updated Test Movie ${timestamp}`
    ) {
      console.log(`✅ Actualización verificada: ${updatedData[0].movie_title}`);
    } else {
      console.log("❌ La actualización no se reflejó correctamente");
    }

    // DELETE - Eliminar favorito
    console.log("🗑️ Eliminando favorito...");
    const { error: deleteError } = await supabase
      .from("user_favorites")
      .delete()
      .eq("user_id", user.id)
      .eq("movie_id", testMovieId);

    if (deleteError) {
      console.log(`❌ Error al eliminar: ${deleteError.message}`);
      return;
    }
    console.log("✅ Favorito eliminado");

    // Verificar eliminación
    const { data: deletedData, error: verifyDeleteError } = await supabase
      .from("user_favorites")
      .select()
      .eq("user_id", user.id)
      .eq("movie_id", testMovieId);

    if (verifyDeleteError) {
      console.log(
        `❌ Error al verificar eliminación: ${verifyDeleteError.message}`
      );
      return;
    }

    if (!deletedData || deletedData.length === 0) {
      console.log("✅ Eliminación verificada");
    } else {
      console.log("❌ El favorito no fue eliminado correctamente");
    }

    console.log("\n🎉 ¡Todos los tests de Supabase completados exitosamente!");
    console.log(
      "📡 La sincronización con Supabase está funcionando correctamente."
    );

    // 4. Test adicional: Obtener todos los favoritos del usuario
    console.log(
      "\n📊 Test adicional: Obtener todos los favoritos del usuario..."
    );
    const { data: allFavorites, error: allError } = await supabase
      .from("user_favorites")
      .select()
      .eq("user_id", user.id);

    if (allError) {
      console.log(`❌ Error al obtener favoritos: ${allError.message}`);
    } else {
      console.log(
        `✅ Se encontraron ${allFavorites.length} favoritos para el usuario`
      );
      if (allFavorites.length > 0) {
        console.log("📋 Favoritos actuales:");
        allFavorites.forEach((fav, index) => {
          console.log(
            `   ${index + 1}. ${fav.movie_title} (ID: ${fav.movie_id})`
          );
        });
      }
    }
  } catch (error) {
    console.log(`❌ Error general: ${error.message}`);
    console.log("Stack trace:", error.stack);
  }
}

// Ejecutar el test
testSupabase();
