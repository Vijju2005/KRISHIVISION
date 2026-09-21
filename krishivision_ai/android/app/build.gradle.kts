plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

var mapsApiKey = System.getenv("MAPS_API_KEY") ?: ""
if (mapsApiKey.isEmpty() && project.hasProperty("dart-defines")) {
    try {
        val defines = project.property("dart-defines") as String
        // Decode base64 if needed (modern flutter base64 encodes dart-defines)
        val decoded = try {
            String(Base64.getDecoder().decode(defines))
        } catch (_: Exception) {
            defines
        }
        for (define in decoded.split(",")) {
            val parts = define.split("=")
            if (parts.size == 2 && parts[0] == "MAPS_API_KEY") {
                mapsApiKey = parts[1]
            }
        }
    } catch (_: Exception) {}
}

if (mapsApiKey.isEmpty()) {
    mapsApiKey = localProperties.getProperty("MAPS_API_KEY") ?: localProperties.getProperty("maps.api.key") ?: "YOUR_GOOGLE_MAPS_API_KEY"
}

android {
    namespace = "com.example.krishivision_ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.krishivision_ai"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}
