# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Hive
-keep class * extends com.google.flatbuffers.Table { *; }
-keep class * implements com.google.flatbuffers.FlatBufferBuilder { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Keep enums
-keepclassmembers enum * { *; }

# Play Core (referenced by Flutter embedding, not used directly)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
