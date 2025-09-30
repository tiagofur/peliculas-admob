// DEBUG SCRIPT - Ejecutar en Console de Chrome (F12)
// Este script te mostrará exactamente qué está pasando con tu perfil

console.log("🔍 DIAGNÓSTICO DE PERFIL - DEBUG MODE");
console.log("=".repeat(80));

// Función para mostrar logs con estilo
function log(emoji, msg, data = null) {
  console.log(`${emoji} ${msg}`);
  if (data) console.log(data);
}

// Función para mostrar errores
function error(msg, err = null) {
  console.error(`❌ ${msg}`);
  if (err) console.error(err);
}

// Función principal de diagnóstico
async function diagnosticarPerfil() {
  try {
    log("📋", "PASO 1: Verificando localStorage y cache");
    console.log("LocalStorage keys:", Object.keys(localStorage));

    // Buscar cualquier dato relacionado con perfil en localStorage
    Object.keys(localStorage).forEach((key) => {
      if (
        key.toLowerCase().includes("profile") ||
        key.toLowerCase().includes("user")
      ) {
        log("  📦", `${key}:`, localStorage.getItem(key)?.substring(0, 100));
      }
    });

    log("📋", "\nPASO 2: Verificando sessionStorage");
    Object.keys(sessionStorage).forEach((key) => {
      if (
        key.toLowerCase().includes("profile") ||
        key.toLowerCase().includes("user")
      ) {
        log("  📦", `${key}:`, sessionStorage.getItem(key)?.substring(0, 100));
      }
    });

    log("📋", "\nPASO 3: Verificando Supabase auth");

    // Buscar cliente Supabase
    const supabase = window.supabaseClient || window._supabase;
    if (!supabase) {
      error("No se encontró cliente Supabase en window");
      log("💡", "Intentando encontrar en otros lugares...");

      // Buscar en todas las propiedades del window
      const supabaseKeys = Object.keys(window).filter((k) =>
        k.toLowerCase().includes("supabase")
      );
      log("🔎", 'Claves con "supabase" en window:', supabaseKeys);

      return;
    }

    log("✅", "Cliente Supabase encontrado");

    // Verificar sesión actual
    const { data: sessionData, error: sessionError } =
      await supabase.auth.getSession();
    if (sessionError) {
      error("Error obteniendo sesión:", sessionError);
      return;
    }

    log("✅", "Sesión obtenida");
    log(
      "  👤",
      "Usuario:",
      sessionData?.session?.user?.email || "No autenticado"
    );
    log("  🆔", "User ID:", sessionData?.session?.user?.id || "N/A");

    if (!sessionData?.session?.user) {
      error("No hay usuario autenticado");
      log("💡", "Debes hacer login primero");
      return;
    }

    const userId = sessionData.session.user.id;

    log("📋", "\nPASO 4: Consultando perfil en Supabase");

    // Query directa a la tabla
    const { data: profileData, error: profileError } = await supabase
      .from("user_profiles")
      .select("*")
      .eq("user_id", userId)
      .maybeSingle();

    if (profileError) {
      error("Error consultando perfil:", profileError);
      log("💡", "Posibles causas:");
      console.log("  - Tabla no existe");
      console.log("  - RLS bloqueando acceso");
      console.log("  - Columnas incorrectas");

      // Intentar query más simple
      log("🔄", "Intentando query simplificada...");
      const { data: simpleData, error: simpleError } = await supabase
        .from("user_profiles")
        .select("id, user_id, display_name")
        .eq("user_id", userId)
        .maybeSingle();

      if (simpleError) {
        error("Query simplificada también falló:", simpleError);
      } else {
        log("✅", "Query simplificada funcionó:", simpleData);
      }

      return;
    }

    if (!profileData) {
      error("No se encontró perfil en la base de datos");
      log("💡", "El perfil debería crearse automáticamente. Verifica:");
      console.log("  1. Trigger handle_new_user() en Supabase");
      console.log("  2. Función _ensureDefaultProfile() en el código");

      // Intentar crear perfil manualmente
      log("🔄", "Intentando crear perfil...");
      const { data: newProfile, error: createError } = await supabase
        .from("user_profiles")
        .insert({
          user_id: userId,
          display_name:
            sessionData.session.user.email?.split("@")[0] || "Usuario",
          full_name:
            sessionData.session.user.user_metadata?.full_name ||
            sessionData.session.user.email?.split("@")[0] ||
            "Usuario",
          email: sessionData.session.user.email,
        })
        .select()
        .single();

      if (createError) {
        error("Error creando perfil:", createError);
      } else {
        log("✅", "¡Perfil creado exitosamente!", newProfile);
      }

      return;
    }

    log("✅", "Perfil encontrado en BD");
    console.table({
      ID: profileData.id,
      "User ID": profileData.user_id,
      "Display Name": profileData.display_name,
      "Full Name": profileData.full_name,
      Username: profileData.username || "null",
      Email: profileData.email,
      "Avatar URL": profileData.avatar_url ? "Sí" : "null",
      "Avatar Hash": profileData.avatar_hash || "null",
      Created: new Date(profileData.created_at).toLocaleString("es-ES"),
      Updated: profileData.updated_at
        ? new Date(profileData.updated_at).toLocaleString("es-ES")
        : "null",
    });

    log("📋", "\nPASO 5: Verificando RLS y permisos");

    // Intentar UPDATE para ver si tenemos permisos
    const { error: updateTestError } = await supabase
      .from("user_profiles")
      .update({ last_synced_at: new Date().toISOString() })
      .eq("user_id", userId);

    if (updateTestError) {
      error("No tienes permisos de UPDATE:", updateTestError);
      log("💡", "Necesitas configurar políticas RLS correctamente");
    } else {
      log("✅", "Permisos de UPDATE: OK");
    }

    log("📋", "\nPASO 6: Verificando avatar (si existe)");

    if (profileData.avatar_url) {
      log("🖼️", "Avatar URL:", profileData.avatar_url);
      log("🔑", "Avatar Hash:", profileData.avatar_hash || "NO HASH");

      // Intentar cargar la imagen
      try {
        const response = await fetch(profileData.avatar_url, {
          method: "HEAD",
        });
        if (response.ok) {
          log("✅", "Avatar accesible");
          log("  📊", "Content-Type:", response.headers.get("content-type"));
          log(
            "  📏",
            "Content-Length:",
            response.headers.get("content-length")
          );
        } else {
          error(`Avatar no accesible (${response.status})`);
          log("💡", "Verifica políticas de Storage");
        }
      } catch (err) {
        error("Error cargando avatar:", err);
      }
    } else {
      log("ℹ️", "Usuario no tiene avatar");
    }

    log("📋", "\nPASO 7: Verificando cache del navegador");

    // Verificar IndexedDB (donde cached_network_image guarda las imágenes)
    const dbs = await indexedDB.databases();
    log(
      "🗄️",
      "IndexedDB databases:",
      dbs.map((db) => db.name)
    );

    // Buscar cache relacionado con imágenes
    const cacheNames = await caches.keys();
    log("💾", "Cache Storage:", cacheNames);

    console.log("\n" + "=".repeat(80));
    log("🎉", "DIAGNÓSTICO COMPLETADO");
    console.log("\n📋 RESUMEN:");
    console.log(`  Usuario: ${sessionData.session.user.email}`);
    console.log(
      `  Perfil en BD: ${profileData ? "✅ Existe" : "❌ No existe"}`
    );
    console.log(
      `  Avatar: ${
        profileData?.avatar_url ? "✅ Configurado" : "ℹ️ Sin avatar"
      }`
    );

    if (profileData) {
      console.log("\n💡 SIGUIENTE PASO:");
      console.log(
        "  1. Si ves el perfil aquí pero no en la app, el problema es en el código Flutter"
      );
      console.log("  2. Abre DevTools de la app (F12 en la ventana de la app)");
      console.log(
        '  3. Busca logs que digan "UserProfileNotifier" o "UserProfileRepository"'
      );
      console.log("  4. Comparte esos logs para diagnosticar el problema");
    }
  } catch (err) {
    error("ERROR GENERAL:", err);
    console.error(err.stack);
  }
}

// Auto-ejecutar
diagnosticarPerfil();
