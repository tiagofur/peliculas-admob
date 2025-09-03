// Script para verificar datos específicos de un usuario en Supabase
const { createClient } = require("@supabase/supabase-js");

const supabaseUrl = "https://fyzujpifkzftweynrudh.supabase.co";
const supabaseKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5enVqcGlma3pmdHdleW5ydWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUzNTkxOTgsImV4cCI6MjA3MDkzNTE5OH0.-wnFtwyfKuasSJ9GDvhOgKLgfz-clpqnMF1u-lC8sBg";

async function checkUserData(userEmail, userPassword) {
  console.log("🔍 VERIFICANDO DATOS DEL USUARIO\n");
  console.log("═".repeat(60));
  console.log(`📧 Email: ${userEmail}`);
  console.log("─".repeat(60));

  try {
    // 1. Crear cliente Supabase
    const supabase = createClient(supabaseUrl, supabaseKey);
    console.log("✅ Cliente Supabase inicializado\n");

    // 2. Intentar autenticación con las credenciales del usuario
    console.log("🔐 AUTENTICANDO USUARIO...");
    const { data: loginData, error: loginError } =
      await supabase.auth.signInWithPassword({
        email: userEmail,
        password: userPassword,
      });

    if (loginError) {
      console.log(`❌ Error de autenticación: ${loginError.message}`);
      
      if (loginError.message.includes("Invalid login credentials")) {
        console.log("\n💡 POSIBLES CAUSAS:");
        console.log("   • Email o contraseña incorrectos");
        console.log("   • Usuario no registrado en Supabase");
        console.log("   • Email no confirmado (si está habilitada la confirmación)");
      }
      
      return;
    }

    const user = loginData.user;
    console.log(`✅ Autenticación exitosa!`);
    console.log(`👤 Usuario ID: ${user.id}`);
    console.log(`📧 Email: ${user.email}`);
    console.log(`📅 Creado: ${new Date(user.created_at).toLocaleString()}`);
    console.log(`✉️ Email confirmado: ${user.email_confirmed_at ? 'Sí' : 'No'}`);

    // 3. Verificar favoritos del usuario
    console.log("\n🎬 VERIFICANDO FAVORITOS...");
    console.log("─".repeat(40));
    
    const { data: favorites, error: favoritesError } = await supabase
      .from("user_favorites")
      .select("*")
      .eq("user_id", user.id)
      .order("updated_at", { ascending: false });

    if (favoritesError) {
      console.log(`❌ Error consultando favoritos: ${favoritesError.message}`);
      console.log(`   Código: ${favoritesError.code}`);
      
      if (favoritesError.message.includes("permission denied")) {
        console.log("\n🔒 PROBLEMA DE PERMISOS:");
        console.log("   Las políticas RLS están bloqueando el acceso");
        console.log("   Verifica que las políticas permitan SELECT para el usuario autenticado");
      }
    } else {
      console.log(`📊 Total de favoritos encontrados: ${favorites.length}`);
      
      if (favorites.length > 0) {
        console.log("\n🎭 LISTA DE FAVORITOS:");
        favorites.forEach((fav, index) => {
          console.log(`${index + 1}. ${fav.movie_title} (ID: ${fav.movie_id})`);
          console.log(`   📅 Agregado: ${new Date(fav.updated_at).toLocaleString()}`);
          console.log(`   ⭐ Rating: ${fav.movie_vote_average}`);
          console.log(`   📝 Descripción: ${fav.movie_overview?.substring(0, 100)}...`);
          console.log("");
        });
      } else {
        console.log("📭 No se encontraron favoritos para este usuario");
        console.log("\n💡 POSIBLES RAZONES:");
        console.log("   • El usuario no ha agregado favoritos aún");
        console.log("   • Los favoritos se están guardando con un user_id diferente");
        console.log("   • Hay un problema en la sincronización desde la app");
      }
    }

    // 4. Verificar watchlist del usuario
    console.log("\n📺 VERIFICANDO WATCHLIST...");
    console.log("─".repeat(40));
    
    const { data: watchlist, error: watchlistError } = await supabase
      .from("user_watchlist")
      .select("*")
      .eq("user_id", user.id)
      .order("updated_at", { ascending: false });

    if (watchlistError) {
      console.log(`❌ Error consultando watchlist: ${watchlistError.message}`);
    } else {
      console.log(`📊 Total de películas en watchlist: ${watchlist.length}`);
      
      if (watchlist.length > 0) {
        console.log("\n🎬 WATCHLIST:");
        watchlist.slice(0, 5).forEach((item, index) => {
          console.log(`${index + 1}. ${item.movie_title} (ID: ${item.movie_id})`);
        });
        if (watchlist.length > 5) {
          console.log(`   ... y ${watchlist.length - 5} más`);
        }
      }
    }

    // 5. Verificar películas vistas
    console.log("\n👁️ VERIFICANDO PELÍCULAS VISTAS...");
    console.log("─".repeat(40));
    
    const { data: watched, error: watchedError } = await supabase
      .from("user_watched_movies")
      .select("*")
      .eq("user_id", user.id)
      .order("updated_at", { ascending: false });

    if (watchedError) {
      console.log(`❌ Error consultando películas vistas: ${watchedError.message}`);
    } else {
      console.log(`📊 Total de películas vistas: ${watched.length}`);
      
      if (watched.length > 0) {
        console.log("\n🎭 PELÍCULAS VISTAS RECIENTES:");
        watched.slice(0, 5).forEach((item, index) => {
          console.log(`${index + 1}. ${item.movie_title} (ID: ${item.movie_id})`);
          console.log(`   📅 Vista: ${new Date(item.updated_at).toLocaleString()}`);
        });
        if (watched.length > 5) {
          console.log(`   ... y ${watched.length - 5} más`);
        }
      }
    }

    // 6. Verificar listas personalizadas
    console.log("\n📋 VERIFICANDO LISTAS PERSONALIZADAS...");
    console.log("─".repeat(40));
    
    const { data: customLists, error: customListsError } = await supabase
      .from("user_custom_lists")
      .select("*")
      .eq("user_id", user.id)
      .order("updated_at", { ascending: false });

    if (customListsError) {
      console.log(`❌ Error consultando listas personalizadas: ${customListsError.message}`);
    } else {
      console.log(`📊 Total de listas personalizadas: ${customLists.length}`);
      
      if (customLists.length > 0) {
        console.log("\n📝 LISTAS PERSONALIZADAS:");
        customLists.forEach((list, index) => {
          console.log(`${index + 1}. ${list.name}`);
          console.log(`   📝 Descripción: ${list.description || 'Sin descripción'}`);
          console.log(`   📅 Creada: ${new Date(list.created_at).toLocaleString()}`);
        });
      }
    }

    // 7. Resumen final
    console.log("\n📊 RESUMEN FINAL");
    console.log("═".repeat(40));
    console.log(`👤 Usuario: ${user.email}`);
    console.log(`🎬 Favoritos: ${favorites?.length || 0}`);
    console.log(`📺 Watchlist: ${watchlist?.length || 0}`);
    console.log(`👁️ Películas vistas: ${watched?.length || 0}`);
    console.log(`📋 Listas personalizadas: ${customLists?.length || 0}`);
    
    const totalItems = (favorites?.length || 0) + (watchlist?.length || 0) + 
                      (watched?.length || 0) + (customLists?.length || 0);
    
    if (totalItems > 0) {
      console.log(`\n🎉 ¡El usuario tiene datos en Supabase!`);
      console.log(`📊 Total de elementos: ${totalItems}`);
    } else {
      console.log(`\n📭 El usuario no tiene datos guardados en Supabase`);
      console.log(`\n💡 POSIBLES CAUSAS:`);
      console.log(`   • Es un usuario nuevo sin actividad`);
      console.log(`   • Los datos se están guardando localmente pero no sincronizando`);
      console.log(`   • Hay un problema en el proceso de sincronización`);
    }

  } catch (error) {
    console.log(`❌ Error general: ${error.message}`);
    console.log("Stack trace:", error.stack);
  }
}

// Función principal
async function main() {
  // Obtener credenciales desde argumentos de línea de comandos
  const args = process.argv.slice(2);
  
  if (args.length < 2) {
    console.log("❌ Faltan argumentos");
    console.log("\n📖 USO:");
    console.log("   node check_user_data.js <email> <password>");
    console.log("\n📝 EJEMPLO:");
    console.log("   node check_user_data.js usuario@ejemplo.com mipassword123");
    process.exit(1);
  }
  
  const [email, password] = args;
  await checkUserData(email, password);
}

// Ejecutar si se llama directamente
if (require.main === module) {
  main();
}

module.exports = { checkUserData };