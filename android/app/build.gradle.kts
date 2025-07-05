import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    kotlin("android")
    id("dev.flutter.flutter-gradle-plugin")
}

fun localProperties(): Properties {
    val localPropertiesFile = rootProject.file("local.properties")
    val properties = Properties()
    if (localPropertiesFile.exists()) {
        properties.load(localPropertiesFile.inputStream())
    }
    return properties
}

val flutterVersionCode: String by lazy {
    localProperties().getProperty("flutter.versionCode") ?: "1"
}
val flutterVersionName: String by lazy {
    localProperties().getProperty("flutter.versionName") ?: "1.0"
}

android {
    val keyProperties = Properties()
    val keyPropertiesFile = rootProject.file("android/key.properties")
    if (keyPropertiesFile.exists()) {
        keyProperties.load(FileInputStream(keyPropertiesFile))
    }

    namespace = "com.example.myapp"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        applicationId = "com.example.myapp"
        minSdk = 21
        targetSdk = 34
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String?
            keyPassword = keyProperties["keyPassword"] as String?
            storeFile = if (keyProperties.containsKey("keyAlias")) file("upload-keystore.jks") else null
            storePassword = keyProperties["storePassword"] as String?
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (keyProperties.containsKey("keyAlias")) {
                signingConfig = signingConfigs.getByName("release")
            }
            this.isJniDebuggable = false
            this.isRenderscriptDebuggable = false
            this.isMinifyEnabled = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
}
