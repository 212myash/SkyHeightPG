import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val isKeyPropertiesPresent = keystorePropertiesFile.exists()

if (isKeyPropertiesPresent) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.skyheightpg.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.skyheightpg.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (isKeyPropertiesPresent) {
                val storePath = keystoreProperties.getProperty("storeFile")
                val keyStoreFile = if (storePath != null) {
                    val candidate = file(storePath)
                    if (candidate.exists()) candidate else rootProject.file(storePath)
                } else null

                if (keyStoreFile == null || !keyStoreFile.exists()) {
                    throw GradleException("Release keystore file '${storePath}' specified in key.properties was not found.")
                }

                storeFile = keyStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (isKeyPropertiesPresent) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Enforce Condition 1: Never silently fall back to debug signing for release builds
                signingConfig = null
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// Strict Enforcement of Condition 1: Block release builds if signing config is missing
gradle.taskGraph.whenReady {
    val isReleaseTask = allTasks.any {
        it.name.contains("Release", ignoreCase = true) && !it.name.contains("Test", ignoreCase = true)
    }
    if (isReleaseTask && !isKeyPropertiesPresent) {
        throw GradleException(
            "CRITICAL RELEASE SIGNING BLOCKER:\n" +
            "Release keystore configuration file 'key.properties' was not found.\n" +
            "Per production security requirements, release builds are strictly forbidden from using debug signing.\n" +
            "Please configure 'mobile/android/key.properties' with valid credentials before building."
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Apply Google Services Plugin conditionally when google-services.json is present
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
