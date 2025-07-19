# Flutter proguard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep Flutter engine
-dontwarn io.flutter.embedding.**

# Keep permission handler
-keep class com.baseflow.permissionhandler.** { *; }

# Keep connectivity plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# Keep local notifications
-keep class com.dexterous.** { *; }

# Keep share plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# Keep file picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Keep SQLite
-keep class io.flutter.plugins.sqflite.** { *; }

# Keep device info plus
-keep class dev.fluttercommunity.plus.device_info.** { *; }

# Keep path provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Keep url launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Keep mobile scanner
-keep class dev.steenbakker.mobile_scanner.** { *; }

# Gson rules
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep model classes for Gson
-keep class com.example.arsiv_uygulamasi.models.** { *; }

# General Android rules
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

-keep class * extends java.util.ListResourceBundle {
    protected java.lang.Object[][] getContents();
} 