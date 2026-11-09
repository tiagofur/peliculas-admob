// Valores por entorno sin secretos en git: `~/.gradle/gradle.properties` o `-P` en CI.
// Sin definir, se usan los IDs de prueba oficiales de Google (igual que el xcconfig de iOS).
fun prop(name: String, fallback: String = ""): String =
  (project.findProperty(name) as String?)?.takeIf { it.isNotBlank() } ?: fallback

val admobTestAppId = "ca-app-pub-3940256099942544~3347511713"
val admobTestBannerId = "ca-app-pub-3940256099942544/9214589741"

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
    applicationId = "mx.creapolis.peliculas.android"
    minSdk = 26
    targetSdk = 36
    versionCode = 1
    versionName = "0.1.0"

    buildConfigField("String", "PRIVACY_URL", "\"https://creapolis.dev/privacidad/\"")
    buildConfigField("String", "TERMS_URL", "\"https://creapolis.dev/terminos/\"")
    buildConfigField("String", "SUPPORT_URL", "\"https://creapolis.dev/es/contacto/\"")
    // Client ID *web* de OAuth (Credential Manager lo pide para emitir el ID token que valida
    // el backend en GOOGLE_CLIENT_IDS). Vacío ⇒ el botón de Google no aparece.
    buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", "\"${prop("GOOGLE_WEB_CLIENT_ID")}\"")
  }

  buildTypes {
    debug {
      // El emulador alcanza el host por 10.0.2.2 (backend Go local en 8787).
      buildConfigField("String", "API_BASE_URL", "\"http://10.0.2.2:8787\"")
      manifestPlaceholders["admobAppId"] = admobTestAppId
      buildConfigField("String", "ADMOB_BANNER_ID", "\"$admobTestBannerId\"")
    }
    release {
      isMinifyEnabled = true
      isShrinkResources = true
      proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
      buildConfigField("String", "API_BASE_URL", "\"https://api-peliculas.creapolis.dev\"")
      manifestPlaceholders["admobAppId"] = prop("ADMOB_APP_ID", admobTestAppId)
      buildConfigField("String", "ADMOB_BANNER_ID", "\"${prop("ADMOB_BANNER_ID", admobTestBannerId)}\"")
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
  implementation(libs.play.services.ads)
  implementation(libs.androidx.glance.appwidget)
  implementation(libs.androidx.glance.material3)
  implementation(libs.androidx.work.runtime.ktx)
  implementation(libs.google.ump)
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
