// Plugins declarados una sola vez (catálogo en gradle/libs.versions.toml).
// Kotlin-android no se declara: AGP 9+ lo trae integrado.
plugins {
  alias(libs.plugins.android.application) apply false
  alias(libs.plugins.kotlin.compose) apply false
  alias(libs.plugins.kotlin.serialization) apply false
}
