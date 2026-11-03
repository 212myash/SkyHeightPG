# ==============================================================================
# Sky Height PG — Minimal Production R8 / ProGuard Configuration
# ==============================================================================

# Flutter Engine & Embedding Native Bridge
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Flutter Secure Storage & AndroidX Crypto Keystore Operations
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# AndroidX Core & Support Components
-keep class androidx.core.** { *; }
-dontwarn androidx.core.**

# Suppress harmless warnings from unreferenced transitive library paths
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn com.google.crypto.tink.**

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
