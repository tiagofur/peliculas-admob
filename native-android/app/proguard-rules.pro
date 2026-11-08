# kotlinx.serialization + OkHttp: sin reflexión runtime.
-dontwarn okhttp3.internal.platform.**
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-if @kotlinx.serialization.Serializable class **
-keepclassmembers class <1> {
  static <1>$Companion Companion;
}
-if @kotlinx.serialization.Serializable class ** {
  static **$* *;
}
-keepclassmembers class <2>$<3> {
  kotlinx.serialization.KSerializer serializer(...);
}
