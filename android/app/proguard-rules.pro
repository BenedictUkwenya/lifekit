# Stripe configuration
-dontwarn com.stripe.android.pushProvisioning.**
-keep class com.stripe.android.pushProvisioning.** { *; }
-dontwarn com.reactnativestripesdk.**
-keep class com.reactnativestripesdk.** { *; }

# General Flutter wrapper safety
-keep class com.stripe.android.** { *; }
-dontwarn com.stripe.android.**