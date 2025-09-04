// Script de diagnóstico completo para identificar por qué no se guardan favoritos en Supabase
const { createClient } = require("@supabase/supabase-js");

const supabaseUrl = "https://fyzujpifkzftweynrudh.supabase.co";
const supabaseKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTkxOTgsImV4cCI6MjA3MDkzNTE5OH0.-wnFtwyfKuasSJ9GDvhOgKLgfz-clpqnMF1u-lC8sBg";

async function diagnosticSync() {
  console.log("🔍 DIAGNÓSTICO COMPLETO DE SINCRONIZACIÓN\n");
  console.log("═".repeat(60));

  try {
    // 1. Crear cliente y verificar conexión
    const supabase = createClient(supabaseUrl, supabaseKey);
    console.log("✅ Cliente Supabase inicializado\n");

    // 2. Verificar la estructura de la tabla
    console.log("🏗️ VERIFICANDO ESTRUCTURA DE LA TABLA user_favorites");
    console.log("─".repeat(50));

    try {
      // Usar una consulta que nos dé información sobre la tabla sin datos
      const { data: tableInfo, error: tableError } = await supabase
        .from("user_favorites")
        .select("*")
        .limit(0);

      if (tableError) {
        console.log(`❌ Error accediendo a la tabla: ${tableError.message}`);
        console.log(`   Código: ${tableError.code}`);
        console.log(`   Detalles: ${tableError.details}`);
        console.log(`   Pista: ${tableError.hint}`);
        return;
      } else {
        console.log("✅ Tabla user_favorites existe y es accesible");
      }
    } catch (e) {
      console.log(`❌ Error verificando tabla: ${e.message}`);
      return;
    }

    // 3. Verificar políticas RLS
    console.log("\n🔒 VERIFICANDO POLÍTICAS RLS");
    console.log("─".repeat(30));

    // Intentar insertar sin autenticación para ver el mensaje de error específico
    try {
      const testData = {
        user_id: "test-user-id",
        movie_id: 999999,
        movie_title: "Test Movie",
        movie_poster_path: "/test.jpg",
        movie_backdrop_path: "/test_backdrop.jpg",
        movie_overview: "Test overview",
        movie_release_date: "2023-01-01",
        movie_vote_average: 8.5,
        last_modified_at: new Date().toISOString(),
      };

      const { data: insertData, error: insertError } = await supabase
        .from("user_favorites")
        .insert(testData);

      if (insertError) {
        if (insertError.message.includes("policy")) {
          console.log("✅ RLS está activo (necesita autenticación)");
          console.log(`   Mensaje: ${insertError.message}`);
        } else {
          console.log(`⚠️ Error inesperado: ${insertError.message}`);
        }
      } else {
        console.log("⚠️ ADVERTENCIA: Se pudo insertar sin autenticación!");
        console.log(
          "   Esto indica que RLS podría no estar configurado correctamente"
        );
      }
    } catch (e) {
      console.log(`❌ Error en test de inserción: ${e.message}`);
    }

    // 4. Test de autenticación con usuario temporal
    console.log("\n🔐 PROBANDO AUTENTICACIÓN Y SINCRONIZACIÓN");
    console.log("─".repeat(45));

    const timestamp = Date.now();
    const testEmail = `debug-${timestamp}@peliculas.com`;
    const testPassword = "TestPassword123!";

    console.log(`📧 Email de prueba: ${testEmail}`);

    let user = null;

    // Intentar registro
    console.log("📝 Intentando registro...");
    const { data: signUpData, error: signUpError } = await supabase.auth.signUp(
      {
        email: testEmail,
        password: testPassword,
        options: {
          emailRedirectTo: undefined,
        },
      }
    );

    if (signUpError) {
      console.log(`❌ Error en registro: ${signUpError.message}`);

      // Si el error es de confirmación de email, intentar con usuario existente
      if (signUpError.message.includes("confirmation")) {
        console.log("⚠️ Se requiere confirmación de email");
        console.log("💡 Probando con login directo...");

        // Intentar con un usuario que podría ya existir
        const { data: loginData, error: loginError } =
          await supabase.auth.signInWithPassword({
            email: "test@example.com", // Usuario genérico
            password: "password123",
          });

        if (loginError) {
          console.log(`❌ Login también falló: ${loginError.message}`);
          console.log("\n🎯 PROBLEMA IDENTIFICADO:");
          console.log(
            "   1. Se requiere confirmación de email para nuevos usuarios"
          );
          console.log("   2. No hay usuarios pre-existentes para probar");
          console.log("\n💡 SOLUCIONES:");
          console.log(
            "   A. Deshabilitar confirmación de email en Supabase Dashboard:"
          );
          console.log('      Auth > Settings > "Confirm email" = OFF');
          console.log("   B. O configurar un servicio de email válido");
          console.log(
            "   C. O crear un usuario manualmente en Supabase Dashboard"
          );
          return;
        } else {
          user = loginData.user;
          console.log(`✅ Login exitoso con usuario existente: ${user.email}`);
        }
      }
    } else {
      if (signUpData.user) {
        user = signUpData.user;
        console.log(`✅ Registro exitoso: ${user.email}`);

        // Verificar si necesita confirmación
        if (!user.email_confirmed_at) {
          console.log("⚠️ Usuario registrado pero email no confirmado");
          console.log("   Esto puede impedir algunas operaciones");
        }
      }
    }

    if (!user) {
      console.log("\n❌ No se pudo autenticar ningún usuario");
      console.log("💡 Para solucionar este problema:");
      console.log("   1. Ve a Supabase Dashboard > Auth > Settings");
      console.log('   2. Desactiva "Confirm email" temporalmente');
      console.log("   3. O configura un proveedor de email válido");
      return;
    }

    // 5. Test de inserción con usuario autenticado
    console.log("\n📊 PROBANDO INSERCIÓN CON USUARIO AUTENTICADO");
    console.log("─".repeat(45));

    // Verificar sesión actual
    const { data: sessionData, error: sessionError } =
      await supabase.auth.getSession();
    if (!sessionData.session) {
      console.log("❌ No hay sesión activa después de autenticación");
      console.log(
        "   Esto puede indicar un problema con la configuración de Supabase"
      );
      return;
    }

    console.log("✅ Sesión activa confirmada");
    console.log(`👤 Usuario de sesión: ${sessionData.session.user.email}`);

    // Intentar insertar un favorito
    const movieTestData = {
      user_id: user.id,
      movie_id: 123456,
      movie_title: `Película de Prueba ${timestamp}`,
      movie_poster_path: "/poster_test.jpg",
      movie_backdrop_path: "/backdrop_test.jpg",
      movie_overview:
        "Esta es una película de prueba para verificar la sincronización",
      movie_release_date: "2023-01-01",
      movie_vote_average: 8.5,
      last_modified_at: new Date().toISOString(),
    };

    console.log("⬆️ Insertando favorito de prueba...");
    const { data: insertResult, error: insertError } = await supabase
      .from("user_favorites")
      .upsert(movieTestData, { onConflict: "user_id,movie_id" });

    if (insertError) {
      console.log(`❌ Error al insertar favorito: ${insertError.message}`);
      console.log(`   Código: ${insertError.code}`);
      console.log(`   Detalles: ${insertError.details}`);

      if (insertError.message.includes("policy")) {
        console.log("\n🔍 PROBLEMA DE POLÍTICAS RLS:");
        console.log("   Las políticas RLS están bloqueando la inserción");
        console.log(
          "   Verifica que las políticas permitan INSERT para el usuario autenticado"
        );
      }
    } else {
      console.log("✅ Favorito insertado exitosamente!");

      // Verificar que se insertó correctamente
      const { data: verifyData, error: verifyError } = await supabase
        .from("user_favorites")
        .select("*")
        .eq("user_id", user.id)
        .eq("movie_id", 123456);

      if (verifyError) {
        console.log(`❌ Error verificando inserción: ${verifyError.message}`);
      } else if (verifyData && verifyData.length > 0) {
        console.log("✅ Inserción verificada - datos encontrados en Supabase");
        console.log(`📊 Favorito: ${verifyData[0].movie_title}`);

        // Limpiar datos de prueba
        console.log("🧹 Limpiando datos de prueba...");
        await supabase
          .from("user_favorites")
          .delete()
          .eq("user_id", user.id)
          .eq("movie_id", 123456);
        console.log("✅ Datos de prueba limpiados");
      } else {
        console.log("❌ Datos no encontrados después de inserción");
      }
    }

    // 6. Verificar estado final
    console.log("\n📊 RESUMEN DEL DIAGNÓSTICO");
    console.log("═".repeat(40));

    if (!insertError) {
      console.log("🎉 ¡SINCRONIZACIÓN FUNCIONANDO CORRECTAMENTE!");
      console.log("✅ Conexión: OK");
      console.log("✅ Autenticación: OK");
      console.log("✅ Inserción: OK");
      console.log("✅ RLS: Configurado correctamente");
      console.log("\n💡 Si los favoritos no se guardan en la app:");
      console.log("   1. Verifica que el usuario esté autenticado en Flutter");
      console.log(
        "   2. Revisa los logs de la app para errores de sincronización"
      );
      console.log(
        "   3. Comprueba que se llame a toggleFavorite correctamente"
      );
    } else {
      console.log("❌ PROBLEMA ENCONTRADO EN LA SINCRONIZACIÓN");
      console.log("🔧 Pasos para solucionarlo:");

      if (insertError.message.includes("confirmation")) {
        console.log("   1. Deshabilitar confirmación de email en Supabase");
      }

      if (insertError.message.includes("policy")) {
        console.log("   1. Verificar políticas RLS en Supabase Dashboard");
        console.log(
          "   2. Asegurar que permiten INSERT para usuarios autenticados"
        );
      }

      console.log("   3. Verificar que auth.uid() retorna el ID correcto");
    }
  } catch (error) {
    console.log(`❌ Error general en diagnóstico: ${error.message}`);
    console.log("Stack trace:", error.stack);
  }
}

// Ejecutar diagnóstico
diagnosticSync();
