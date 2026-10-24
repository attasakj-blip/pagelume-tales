plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.attasak.pagelume_tales"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.attasak.pagelume_tales"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Upload key for Google Play. CI writes upload-keystore.jks from the
    // UPLOAD_KEYSTORE_BASE64 secret and passes UPLOAD_KEYSTORE_PASSWORD.
    // Without them, release builds use the debug key.
    val uploadPassword = System.getenv("UPLOAD_KEYSTORE_PASSWORD").orEmpty()
    signingConfigs {
        if (uploadPassword.isNotEmpty()) {
            create("upload") {
                storeFile = file("upload-keystore.jks")
                storePassword = uploadPassword
                keyAlias = "upload"
                keyPassword = uploadPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (uploadPassword.isNotEmpty()) "upload" else "debug")
        }
    }
}

flutter {
    source = "../.."
}
