# Keep Flutter's plugin registrant + engine glue.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keepclasseswithmembernames class * { native <methods>; }

# Supabase / GoTrue rely on reflection in places.
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Generic safe defaults.
-dontwarn org.codehaus.mojo.animal_sniffer.**
-dontwarn java.lang.invoke.StringConcatFactory

# Flutter deferred components — we don't use Play Core deferred-install,
# but Flutter's embedding references it. Tell R8 to ignore the missing class.
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
