import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.firebase-perf")
    id("com.google.firebase.crashlytics")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.tommychow.frosty"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time on older Androids.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // ONSET installs alongside the original Frosty rather than replacing it,
        // so it needs its own applicationId. The namespace stays put: relative
        // manifest names and the Kotlin package resolve against it, and the
        // `frosty/ivs-*` MethodChannels are name-based, so nothing native moves.
        // Consequence: this is a distinct app to Android, with its own storage —
        // it starts logged out.
        applicationId = "com.tommychow.frosty.onset"
        minSdk = maxOf(flutter.minSdkVersion, 23) // Amazon IVS player requires Android 6.0+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // key.properties is git-ignored, so a fresh clone has no keystore.
            // Without this fallback the release build gets all the way through
            // compilation and then dies on "SigningConfig release is missing
            // required property storeFile" — a confusing wall for anyone
            // building this for the first time. Debug keys produce an APK that
            // installs and runs; only publishing needs the real keystore.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Amazon IVS player — the same engine the official Twitch app uses, for
    // exact-parity low latency on Twitch HLS streams.
    implementation("com.amazonaws:ivs-player:1.57.0")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
