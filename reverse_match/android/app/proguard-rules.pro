# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Google Sign-In
-keep class com.google.android.gms.auth.api.signin.** { *; }

# Stripe (deep-link return path; no native SDK is bundled but reflective deeplink handling needs this)
-keep class com.reversematch.** { *; }

# Required for JSON serializable models reflectively constructed at runtime
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Don't strip Riverpod / state-management metadata
-keep class dev.rrousselgit.riverpod.** { *; }
