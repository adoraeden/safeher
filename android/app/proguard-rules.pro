# SafeHer Voice Guard: preserve JNA classes and members required by native code
-keep class com.sun.jna.** { *; }
-keepclassmembers class * extends com.sun.jna.** { public *; }

# Preserve Vosk speech recognition classes
-keep class org.vosk.** { *; }

# Suppress warnings for optional desktop-only classes
-dontwarn java.awt.**