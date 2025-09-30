// TEST: Verificar carga de perfil en navegador
// Copiar y pegar en Console del navegador (F12)

(async function testProfileLoading() {
  console.log("🧪 TEST: Verificación de Carga de Perfil");
  console.log("=".repeat(60));

  // 1. Verificar si Supabase está inicializado
  console.log("\n📡 1. Verificando conexión a Supabase...");
  try {
    const supabase = window.supabaseClient || window._supabase;
    if (supabase) {
      console.log("✅ Cliente Supabase encontrado");

      // Verificar usuario actual
      const {
        data: { user },
        error: userError,
      } = await supabase.auth.getUser();

      if (user) {
        console.log(`✅ Usuario autenticado: ${user.id}`);
        console.log(`   Email: ${user.email}`);

        // 2. Verificar si existe perfil en la BD
        console.log("\n🔍 2. Consultando perfil en user_profiles...");
        const { data: profile, error: profileError } = await supabase
          .from("user_profiles")
          .select("*")
          .eq("user_id", user.id)
          .maybeSingle();

        if (profileError) {
          console.error("❌ Error consultando perfil:", profileError);
          console.log("\n💡 Posibles causas:");
          console.log("   - Tabla user_profiles no existe");
          console.log("   - RLS bloquea acceso");
          console.log("   - Nombre de columnas incorrecto");
          return;
        }

        if (profile) {
          console.log("✅ Perfil encontrado en BD:");
          console.table({
            ID: profile.id,
            "User ID": profile.user_id,
            "Display Name": profile.display_name,
            "Full Name": profile.full_name,
            Username: profile.username,
            Bio: profile.bio ? `${profile.bio.substring(0, 50)}...` : "null",
            "Avatar URL": profile.avatar_url ? "Sí" : "No",
            "Avatar Hash": profile.avatar_hash || "null",
            Stats: profile.stats ? "Sí" : "No",
            Preferences: profile.preferences ? "Sí" : "No",
          });

          // 3. Verificar avatar si existe
          if (profile.avatar_url) {
            console.log("\n🖼️ 3. Verificando avatar...");
            console.log(`   URL: ${profile.avatar_url}`);
            console.log(`   Hash: ${profile.avatar_hash || "NO HASH"}`);
            console.log(
              `   Cache Key: ${profile.avatar_url}_${profile.avatar_hash}`
            );

            // Intentar cargar avatar
            const img = new Image();
            img.onload = () => {
              console.log("✅ Avatar se puede cargar correctamente");
              console.log(`   Dimensiones: ${img.width}x${img.height}`);
            };
            img.onerror = (err) => {
              console.error("❌ Error cargando avatar:", err);
              console.log("💡 Verificar política de Storage en Supabase");
            };
            img.src = profile.avatar_url;
          } else {
            console.log("\nℹ️ Usuario no tiene avatar configurado");
          }

          // 4. Verificar estructura de datos
          console.log("\n📊 4. Verificando estructura de datos...");
          const requiredColumns = [
            "id",
            "user_id",
            "display_name",
            "created_at",
            "updated_at",
          ];
          const optionalColumns = [
            "username",
            "bio",
            "avatar_url",
            "avatar_hash",
            "stats",
            "preferences",
          ];

          const missingRequired = requiredColumns.filter(
            (col) => !(col in profile)
          );
          const missingOptional = optionalColumns.filter(
            (col) => !(col in profile)
          );

          if (missingRequired.length > 0) {
            console.error(
              `❌ Faltan columnas REQUERIDAS: ${missingRequired.join(", ")}`
            );
          } else {
            console.log("✅ Todas las columnas requeridas presentes");
          }

          if (missingOptional.length > 0) {
            console.warn(
              `⚠️ Faltan columnas OPCIONALES: ${missingOptional.join(", ")}`
            );
          } else {
            console.log("✅ Todas las columnas opcionales presentes");
          }
        } else {
          console.warn("⚠️ No se encontró perfil en la BD");
          console.log("\n💡 La aplicación debería crear uno automáticamente");
          console.log(
            "   Verificar logs de: UserProfileRepositoryImpl._ensureDefaultProfile()"
          );
        }
      } else {
        console.error("❌ No hay usuario autenticado");
        console.log("💡 Hacer login primero en http://localhost:3000");
      }
    } else {
      console.error("❌ Cliente Supabase no encontrado en window");
      console.log("💡 La aplicación debe inicializar Supabase primero");
    }
  } catch (error) {
    console.error("❌ Error general:", error);
  }

  console.log("\n" + "=".repeat(60));
  console.log("✨ Test completado");
  console.log("\n📋 Próximo paso:");
  console.log(
    "   Si hay errores, seguir guía en docs/PROFILE_LOADING_GUIDE.md"
  );
})();
