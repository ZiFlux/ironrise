import java.util.Properties

// Ключ загрузки для Google Play лежит вне репозитория (см. docs/RELEASE.md).
// Нет файла — релиз подписывается отладочным ключом, сборка не падает.
val releaseKeyFile = file("${System.getProperty("user.home")}/.ironrise/key.properties")
val releaseKey = Properties().apply {
    if (releaseKeyFile.exists()) releaseKeyFile.inputStream().use { load(it) }
}

plugins {
    id("com.android.application")
}

android {
    namespace = "com.ironrise.watch"
    compileSdk = 37

    defaultConfig {
        // Тот же applicationId и ключ подписи, что у телефонного приложения:
        // без этого Wearable Data Layer не свяжет часы и телефон.
        applicationId = "com.ironrise.ironrise"
        // Health Services и Wear OS 3+.
        minSdk = 30
        targetSdk = 36
        // Google Play требует, чтобы коды версий часов и телефона не совпадали:
        // у часов они начинаются с 1 000 000.
        versionCode = 1_000_001
        versionName = "0.1.0"
    }

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

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (releaseKeyFile.exists()) "release" else "debug")
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-ktx:1.10.1")
    // Иначе Play Services тянут fragment 1.0, и запрос разрешений теряет результат.
    implementation("androidx.fragment:fragment-ktx:1.8.5")
    implementation("androidx.lifecycle:lifecycle-service:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.health:health-services-client:1.1.0")
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-guava:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.10.2")
}
