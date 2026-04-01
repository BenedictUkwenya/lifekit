plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.lifekit_frontend"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion



    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }


        lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    
    defaultConfig {
        applicationId = "com.example.lifekit_frontend"
        // minSdk 21 is required by flutter_stripe and FlutterSecureStorage.
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // Signing with debug keys until a release keystore is configured.
            signingConfig = signingConfigs.getByName("debug")

            // Disabled to prevent Stripe, Supabase, and secure-storage classes
            // from being removed or obfuscated during the production build.
            // Re-enable only after adding correct ProGuard keep rules.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
