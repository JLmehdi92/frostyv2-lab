import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // Firebase is optional: these are only put on the classpath here, and
    // applied below when the build has a google-services.json.
    id("com.google.gms.google-services") apply false
    id("com.google.firebase.firebase-perf") apply false
    id("com.google.firebase.crashlytics") apply false
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The repository carries no Firebase config (see README): a build without
// android/app/google-services.json has no Firebase, and the Dart side does
// not start it either unless the FIREBASE_* --dart-defines are given.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.firebase-perf")
    apply(plugin = "com.google.firebase.crashlytics")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "app.onset"
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
        // The Kotlin sources live in the same package (kotlin/app/onset), so
        // relative manifest names (.MainActivity, .BackgroundAudioService)
        // resolve against the namespace.
        applicationId = "app.onset"
        minSdk = maxOf(flutter.minSdkVersion, 23) // IVS needs 6.0+; Flutter 3.38 already requires 7.0 (24)
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
                // Said out loud: a debug-signed release cannot update an
                // install signed with the real key, and nothing else in the
                // build output would hint at why.
                logger.warn(
                    "WARNING: android/key.properties not found; the release " +
                        "build is signed with the DEBUG key.",
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Amazon IVS player, built on the same video technology as Twitch, for
    // low latency on Twitch HLS streams.
    implementation("com.amazonaws:ivs-player:1.57.0")

    implementation("com.google.android.gms:play-services-cast-framework:21.5.0")
    implementation("androidx.mediarouter:mediarouter:1.7.0")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
