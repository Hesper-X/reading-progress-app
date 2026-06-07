plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hespe.reading_progress"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.hespe.reading_progress"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // flutter_local_notifications 需要 core library desugaring
        multiDexEnabled = true

        // V3.5 OCR: ML Kit 只打 arm64-v8a（真机架构），模拟器 x86 翻不了
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildTypes {
        debug {
            // V3.5 OCR 大体积 native lib 打包时禁用压缩避免 OOM
            isCrunchPngs = false
        }
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
        // 排除 Vulkan 验证层（debug 仅用于开发，真机不需要）
        exclude("/lib/arm64-v8a/libVkLayer_khronos_validation.so")
        exclude("/lib/armeabi-v7a/libVkLayer_khronos_validation.so")
        exclude("/lib/x86/libVkLayer_khronos_validation.so")
        exclude("/lib/x86_64/libVkLayer_khronos_validation.so")
    }
}

dependencies {
    // flutter_local_notifications 需要 core library desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // V3.5 OCR: ML Kit 中文文字识别（R8 需要的显式依赖）
    implementation("com.google.mlkit:text-recognition-chinese:16.0.0")
}

flutter {
    source = "../.."
}