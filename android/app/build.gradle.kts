import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// This application ID starts a new installation alongside the legacy app.
// Keep its private signing key unchanged for all subsequent updates.
val updateKeyFile = rootProject.file("key.properties")
val updateKey = Properties()
if (updateKeyFile.exists()) {
    FileInputStream(updateKeyFile).use { updateKey.load(it) }
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").forEach {
        require(!updateKey.getProperty(it).isNullOrBlank()) { "key.properties: missing $it" }
    }
}
require(updateKeyFile.exists() || gradle.startParameter.taskNames.none {
    it.contains("release", ignoreCase = true)
}) { "Release signing requires android/key.properties and the backed-up Arsivim key." }

android {
    namespace = "com.mehmetkarataslar.arsivim"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.mehmetkarataslar.arsivim"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (updateKeyFile.exists()) {
            create("existingInstall") {
                storeFile = rootProject.file(updateKey.getProperty("storeFile"))
                storePassword = updateKey.getProperty("storePassword")
                keyAlias = updateKey.getProperty("keyAlias")
                keyPassword = updateKey.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (updateKeyFile.exists()) "existingInstall" else "debug")
        }
        debug {
            signingConfig = signingConfigs.getByName(if (updateKeyFile.exists()) "existingInstall" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
}
