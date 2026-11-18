import java.util.Properties

// Ключ загрузки для Google Play лежит вне репозитория (см. docs/RELEASE.md).
// Нет файла — релиз подписывается отладочным ключом, сборка не падает.
val releaseKeyFile = file("${System.getProperty("user.home")}/.ironrise/key.properties")
val releaseKey = Properties().apply {
    if (releaseKeyFile.exists()) releaseKeyFile.inputStream().use { load(it) }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ironrise.ironrise"
    // permission_handler требует компиляции под API 37.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            if (releaseKeyFile.exists()) {
                keyAlias = releaseKey.getProperty("keyAlias")
                keyPassword = releaseKey.getProperty("keyPassword")
                storeFile = file(releaseKey.getProperty("storeFile"))
                storePassword = releaseKey.getProperty("storePassword")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ironrise.ironrise"
        manifestPlaceholders["appLabel"] = "IronRise"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Health Connect требует Android 8.0 (API 26) и новее.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        // Отладочная сборка — отдельное приложение «IronRise DEV» со своими данными:
        // её можно поставить рядом с бетой, и она не попадает к бета-тестерам.
        // Телефон и часы в debug оба с суффиксом .dev, поэтому видят друг друга.
        getByName("debug") {
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "IronRise DEV"
        }
        release {
            signingConfig = signingConfigs.getByName(if (releaseKeyFile.exists()) "release" else "debug")
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
    // Пульс с приложения IronRise на Wear OS часах (watch/wearos).
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
    // Открыть страницу приложения в магазине на часах (мастер подключения).
    implementation("androidx.wear:wear-remote-interactions:1.0.0")
}
