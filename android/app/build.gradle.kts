plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "vn.giadinh.nhac_uong_thuoc"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Cần cho thư viện thông báo (flutter_local_notifications).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "vn.giadinh.nhac_uong_thuoc"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Khoá ký cố định để các bản cập nhật cài đè được lên bản cũ (giữ nguyên dữ liệu).
    // Chỉ dùng cho gia đình; giữ repo GitHub ở chế độ Private.
    signingConfigs {
        create("giaDinh") {
            storeFile = file("nhac-uong-thuoc.jks")
            storePassword = "nhacthuoc123"
            keyAlias = "nhacthuoc"
            keyPassword = "nhacthuoc123"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("giaDinh")
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
}
