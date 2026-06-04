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

# Google Play Core — Flutter's embedding references the deferred-components /
# split-install APIs, but the Play Core library is not bundled. Without these
# rules R8 fails the release build with "Missing class
# com.google.android.play.core.*". We don't use deferred components, so it is
# safe to tell R8 to ignore them.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
