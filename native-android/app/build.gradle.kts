import java.util.Properties

// Valores por entorno sin secretos en git: `~/.gradle/gradle.properties` o `-P` en CI.
fun prop(name: String, fallback: String = ""): String =
  (project.findProperty(name) as String?)?.takeIf { it.isNotBlank() } ?: fallback

// Firma de release: `native-android/keystore.properties` (ignorado por git) o las
// mismas claves en `~/.gradle/gradle.properties` / `-P`. Sin ellas el release sale sin firmar.
val keystoreProps = Properties().apply {
  val f = rootProject.file("keystore.properties")
  if (f.exists()) f.inputStream().use { load(it) }
}
fun signing(name: String): String? =
  (keystoreProps.getProperty(name) ?: project.findProperty(name) as String?)?.takeIf { it.isNotBlank() }

plugins {
  alias(libs.plugins.android.application)
  alias(libs.plugins.kotlin.android)
  alias(libs.plugins.kotlin.compose)
  alias(libs.plugins.kotlin.serialization)
}

android {
  namespace = "mx.creapolis.peliculas.android"
  compileSdk = 37

  defaultConfig {
    // Mismo paquete que la app Flutter publicada: la nativa llega como actualización
    // de la ficha existente (firmada con la misma clave de subida, peliculas.jks).
    applicationId = "mx.creapolis.peliculas"
    minSdk = 26
    targetSdk = 36
    // La Flutter publicada va en 1.3.0 (7): la nativa tiene que ser mayor.
    versionCode = 10
    versionName = "2.0.0"

    buildConfigField("String", "PRIVACY_URL", "\"https://creapolis.dev/privacidad/\"")
    buildConfigField("String", "TERMS_URL", "\"https://creapolis.dev/terminos/\"")
    buildConfigField("String", "SUPPORT_URL", "\"https://creapolis.dev/es/contacto/\"")
    // Client ID *web* de OAuth (no es secreto: va dentro de cualquier app). Credential Manager
    // lo pide para emitir el ID token que el backend valida contra GOOGLE_CLIENT_IDS.
    // Tiene que vivir en el mismo proyecto de Google Cloud que el cliente Android
    // (paquete + SHA-1). Se sobrescribe con -PGOOGLE_WEB_CLIENT_ID=….
    buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", "\"${prop("GOOGLE_WEB_CLIENT_ID", "555605887021-fafk3kj39jv02onor43is8q3cn2q9r5s.apps.googleusercontent.com")}\"")
  }

  signingConfigs {
    create("release") {
      signing("PELIS_STORE_FILE")?.let { storeFile = file(it) }
      storePassword = signing("PELIS_STORE_PASSWORD")
      keyAlias = signing("PELIS_KEY_ALIAS")
      keyPassword = signing("PELIS_KEY_PASSWORD")
    }
  }

  buildTypes {
    debug {
      // Convive en el mismo teléfono con la app de Play (otra firma, otro paquete).
      applicationIdSuffix = ".debug"
      // El emulador alcanza el host por 10.0.2.2 (backend Go local en 8787).
      buildConfigField("String", "API_BASE_URL", "\"http://10.0.2.2:8787\"")
    }
    release {
      if (signing("PELIS_STORE_FILE") != null) signingConfig = signingConfigs.getByName("release")
      isMinifyEnabled = true
      isShrinkResources = true
      proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
      buildConfigField("String", "API_BASE_URL", "\"https://api-peliculas.creapolis.dev\"")
    }
  }

  buildFeatures {
    compose = true
    buildConfig = true
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
}

// Kotlin apunta a la misma JVM que Java: compila igual con el JDK 17 o con el de Android Studio.
kotlin {
  compilerOptions {
    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
  }
}

dependencies {
  implementation(libs.kotlinx.coroutines.android)
  implementation(libs.kotlinx.serialization.json)
  implementation(libs.okhttp)
  implementation(libs.coil.compose)
  implementation(libs.coil.network.okhttp)
  implementation(libs.androidx.security.crypto)
  implementation(libs.play.billing)
  implementation(libs.androidx.glance.appwidget)
  implementation(libs.androidx.glance.material3)
  implementation(libs.androidx.work.runtime.ktx)
  implementation(libs.androidx.credentials)
  implementation(libs.androidx.credentials.play)
  implementation(libs.google.id)
  implementation(libs.androidx.lifecycle.process)

  implementation(libs.androidx.activity.compose)
  implementation(libs.androidx.compose.ui)
  implementation(libs.androidx.compose.foundation)
  implementation(libs.androidx.compose.material3)
  implementation(libs.androidx.compose.icons.extended)
  implementation(libs.androidx.compose.ui.tooling.preview)
  implementation(libs.androidx.navigation.compose)
  implementation(libs.androidx.lifecycle.viewmodel.compose)

  debugImplementation(libs.androidx.compose.ui.tooling)

  testImplementation(libs.junit)
  testImplementation(libs.kotlinx.coroutines.test)
  testImplementation(libs.kotlinx.serialization.json)
  testImplementation(libs.okhttp.mockwebserver)
}
