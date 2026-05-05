-keep class com.google.devtools.build.android.desugar.runtime.ThrowableExtension { *; }
# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-dontwarn com.google.devtools.build.android.desugar.runtime.ThrowableExtension

-keep class com.hiennv.flutter_callkit_incoming.** { *; }
#################################################
## 1. Keep or Ignore Java Beans Annotations    ##
#################################################
# If you actually need them at runtime, keep them:
-keep class java.beans.** { *; }

# Otherwise, to only suppress warnings:
-dontwarn java.beans.ConstructorProperties
-dontwarn java.beans.Transient

#################################################
## 2. Keep or Ignore org.w3c.dom Classes       ##
#################################################
-keep class org.w3c.dom.** { *; }
-dontwarn org.w3c.dom.bootstrap.DOMImplementationRegistry

# (Optional) If the library references them but you don't actually use them:
# -dontwarn org.w3c.dom.bootstrap.**

#################################################
## 3. Keep Jackson-related Classes            ##
#################################################
-keep class com.fasterxml.jackson.databind.** { *; }
-keep class com.fasterxml.jackson.core.** { *; }
-dontwarn com.fasterxml.jackson.databind.**
-dontwarn com.fasterxml.jackson.core.**
