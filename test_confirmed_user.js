// Script para crear un usuario confirmado manualmente y probar la sincronización
const { createClient } = require("@supabase/supabase-js");

const supabaseUrl = "https://fyzujpifkzftweynrudh.supabase.co";
const supabaseKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTkxOTgsImV4cCI6MjA3MDkzNTE5OH0.-wnFtwyfKuasSJ9GDvhOgKLgfz-clpqnMF1u-lC8sBg";

async function testWithConfirmedUser() {
  console.log("🔧 PROBANDO CON CONFIGURACIÓN MANUAL\n");

  try {
    const supabase = createClient(supabaseUrl, supabaseKey);
    console.log("✅ Cliente Supabase inicializado\n");

    // Método 1: Probar con signInAnonymously si está habilitado
    console.log("👤 Probando login anónimo...");
    try {
      const { data: anonData, error: anonError } =
        await supabase.auth.signInAnonymously();

      if (anonError) {
        console.log(`❌ Login anónimo no disponible: ${anonError.message}`);
      } else if (anonData.user) {
        console.log(`✅ Usuario anónimo creado: ${anonData.user.id}`);

        // Probar inserción con usuario anónimo
        await testInsertion(supabase, anonData.user);
        return;
      }
    } catch (e) {
      console.log(`❌ Error en login anónimo: ${e.message}`);
    }

    // Método 2: Intentar con un email simple que pueda ser auto-confirmado
    console.log("\n📧 Probando con email simple...");
    const simpleEmail = "test@test.com";
    const simplePassword = "password123";

    // Primero intentar login directo
    const { data: loginData, error: loginError } =
      await supabase.auth.signInWithPassword({
        email: simpleEmail,
        password: simplePassword,
      });

    if (loginData.user && !loginError) {
      console.log(
        `✅ Login exitoso con usuario existente: ${loginData.user.email}`
      );
      await testInsertion(supabase, loginData.user);
      return;
    }

    console.log(`⚠️ No se pudo usar usuario existente: ${loginError?.message}`);

    // Método 3: Registro con confirmación automática (si está configurado)
    console.log("\n🔄 Intentando registro con auto-confirmación...");
    const testEmail = `autotest-${Date.now()}@example.com`;
    const testPassword = "TestPassword123!";

    const { data: signUpData, error: signUpError } = await supabase.auth.signUp(
      {
        email: testEmail,
        password: testPassword,
        options: {
          data: {
            full_name: "Usuario de Prueba",
          },
        },
      }
    );

    if (signUpError) {
      console.log(`❌ Error en registro: ${signUpError.message}`);

      console.log("\n🎯 CONFIGURACIÓN REQUERIDA EN SUPABASE:");
      console.log("═".repeat(50));
      console.log("1. Ve a Supabase Dashboard > Authentication > Settings");
      console.log('2. En "User Signups" sección:');
      console.log('   - ❌ Desactiva "Enable email confirmations"');
      console.log("   - ✅ O configura un proveedor de email válido");
      console.log("3. Alternativamente, crea un usuario manualmente en:");
      console.log('   - Dashboard > Authentication > Users > "Add user"');
      console.log('   - Asegúrate de marcar "Auto Confirm User"');

      return;
    }

    if (signUpData.user) {
      console.log(`✅ Usuario registrado: ${signUpData.user.email}`);

      // Verificar si está confirmado
      if (signUpData.user.email_confirmed_at) {
        console.log("✅ Email auto-confirmado");
        await testInsertion(supabase, signUpData.user);
      } else {
        console.log("⚠️ Email no confirmado automáticamente");
        console.log("💡 Necesitas configurar auto-confirmación en Supabase");
      }
    }
  } catch (error) {
    console.log(`❌ Error general: ${error.message}`);
  }
}

async function testInsertion(supabase, user) {
  console.log(`\n🧪 PROBANDO INSERCIÓN CON USUARIO: ${user.email || user.id}`);
  console.log("─".repeat(50));

  // Verificar sesión
  const { data: sessionData } = await supabase.auth.getSession();
  if (!sessionData.session) {
    console.log("❌ Sin sesión activa");
    return;
  }

  console.log("✅ Sesión activa confirmada");

  // Datos de prueba
  const favoriteData = {
    user_id: user.id,
    movie_id: 999888,
    movie_title: "Película de Prueba Sync",
    movie_poster_path: "/test_poster.jpg",
    movie_backdrop_path: "/test_backdrop.jpg",
    movie_overview: "Película para probar sincronización completa",
    movie_release_date: "2023-01-01",
    movie_vote_average: 9.0,
    updated_at: new Date().toISOString(),
  };

  console.log("⬆️ Insertando favorito...");
  const { data: insertData, error: insertError } = await supabase
    .from("user_favorites")
    .upsert(favoriteData, { onConflict: "user_id,movie_id" });

  if (insertError) {
    console.log(`❌ Error al insertar: ${insertError.message}`);
    console.log(`   Código: ${insertError.code}`);

    if (insertError.message.includes("policy")) {
      console.log("\n🔧 PROBLEMA DE POLÍTICAS RLS:");
      console.log(
        "   - Las políticas RLS están activas pero bloqueando la inserción"
      );
      console.log("   - Verifica que auth.uid() = user_id en la política");
      console.log("   - Posible solución: Revisar las migraciones SQL");
    }
  } else {
    console.log("✅ Favorito insertado exitosamente!");

    // Verificar inserción
    const { data: verifyData, error: verifyError } = await supabase
      .from("user_favorites")
      .select("*")
      .eq("user_id", user.id);

    if (verifyError) {
      console.log(`❌ Error verificando: ${verifyError.message}`);
    } else {
      console.log(
        `✅ Verificación exitosa: ${verifyData.length} favoritos encontrados`
      );

      if (verifyData.length > 0) {
        console.log("📊 Datos encontrados:");
        verifyData.forEach((fav, index) => {
          console.log(
            `   ${index + 1}. ${fav.movie_title} (ID: ${fav.movie_id})`
          );
        });

        console.log("\n🎉 ¡SINCRONIZACIÓN FUNCIONANDO CORRECTAMENTE!");
        console.log("💡 El problema en tu app Flutter es probablemente:");
        console.log("   1. Usuario no está autenticado correctamente");
        console.log(
          "   2. Email no confirmado (necesita configuración en Supabase)"
        );
        console.log("   3. Sesión no activa durante la sincronización");
      }
    }
  }
}

// Ejecutar test
testWithConfirmedUser();
