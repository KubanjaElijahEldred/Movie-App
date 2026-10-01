import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials live in android/key.properties, which is
// git-ignored. When that file is absent (fresh clone, CI without secrets) the
// release build falls back to debug signing so `flutter run --release` and
// local builds still work.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
// Paths inside key.properties are written relative to the android/ directory
// that holds key.properties. Gradle's `file()` resolves against android/app/,
// so resolve these explicitly or the lookup below silently misses and the
// release build quietly falls back to debug signing.
val releaseStoreFile = keystoreProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let { keystorePropertiesFile.parentFile.resolve(it) }
val hasReleaseSigning = releaseStoreFile?.isFile == true

android {
    namespace = "com.bimsina.movies"
    compileSdk = flutter.compileSdkVersion
    // Pinned explicitly instead of via flutter.ndkVersion (28.2.13676358).
    // No plugin here ships prebuilt native C++ for Flutter to link, so a
    // working NDK is only needed for the AGP/CMake toolchain probe.
    // 28.2.13676358 is a ~690 MB download that kept stalling partway on this
    // machine and failed with CXX1101; 27.0.12077973 is already installed and
    // builds this app cleanly. Switch back to flutter.ndkVersion once the SDK
    // manager can fetch 28.x reliably.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.bimsina.movies"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 shrinking is left off deliberately: it needs an on-device pass to
            // confirm the plugins still resolve at runtime. Turn it on together
            // with a proguard-rules.pro once that pass exists.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}