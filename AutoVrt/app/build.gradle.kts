plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.roborazzi)
}

android {
    namespace = "com.example.autovrt"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.autovrt"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = "11"
    }
    buildFeatures {
        compose = true
    }
    testOptions.unitTests {
        isReturnDefaultValues = true
        isIncludeAndroidResources = true
    }
}

dependencies {

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.navigation.compose)
    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)
    testImplementation(libs.androidx.ui.test.junit4.android)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.ui.test.junit4)
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)
}

// VRT画像作成からレポート生成までの自動化タスク
tasks.register("generateVrtImages") {
    group = "vrt"
    description = "VRT画像を生成して正解画像ディレクトリに移動し、レポートを生成する"
    
    doLast {
        println("📸 VRT画像生成を開始します...")
        
        // 1. VRTテストを実行して画像を生成
        exec {
            commandLine("${project.rootDir}/gradlew", ":app:testDebugUnitTest")
        }
        
        println("✅ VRT画像生成完了")
    }
}

tasks.register("moveVrtImagesToExpected") {
    group = "vrt"
    description = "生成されたVRT画像を正解画像ディレクトリに移動する"
    
    doLast {
        println("📁 VRT画像を正解画像ディレクトリに移動中...")
        
        val screenshotsDir = file("${project.projectDir}/__screenshots__")
        val expectedDir = file("${project.projectDir}/.reg/expected")
        
        if (screenshotsDir.exists()) {
            // 既存の正解画像ディレクトリをクリア
            if (expectedDir.exists()) {
                expectedDir.deleteRecursively()
                println("🗑️ 既存の正解画像ディレクトリをクリアしました")
            }
            
            // 正解画像ディレクトリを作成
            expectedDir.mkdirs()
            println("📁 新しい正解画像ディレクトリを作成しました")
            
            // 生成された画像を正解画像ディレクトリにコピー
            screenshotsDir.listFiles()?.forEach { file ->
                if (file.isFile && file.extension == "png") {
                    val targetFile = File(expectedDir, file.name)
                    file.copyTo(targetFile, overwrite = true)
                    println("📋 ${file.name} を正解画像ディレクトリにコピーしました")
                }
            }
            
            // 一時的なスクリーンショットディレクトリを削除
            screenshotsDir.deleteRecursively()
            println("🗑️ 一時的なスクリーンショットディレクトリを削除しました")
        } else {
            println("⚠️ スクリーンショットディレクトリが見つかりません: ${screenshotsDir.absolutePath}")
        }
        
        println("✅ VRT画像の移動完了")
    }
}

// メインタスク: VRT画像生成からレポート生成までを一括実行
tasks.register("vrtWorkflow") {
    group = "vrt"
    description = "VRT画像生成からレポート生成までを一括実行する"
    
    dependsOn("generateVrtImages", "moveVrtImagesToExpected")
    
    doLast {
        println("🎉 VRTワークフローが完了しました！")
    }
}

// 特定のテストクラスのみを対象としたVRT画像生成タスク
tasks.register("generateVrtImagesForTest") {
    group = "vrt"
    description = "指定されたテストクラスのVRT画像を生成する"
    
    doLast {
        val testPattern = project.findProperty("testPattern") as String? ?: "*ScreenTest*"
        println("📸 テストパターン '${testPattern}' のVRT画像生成を開始します...")
        
        // 指定されたテストパターンでVRTテストを実行
        exec {
            commandLine("${project.rootDir}/gradlew", ":app:testDebugUnitTest", "--tests", testPattern)
        }
        
        println("✅ VRT画像生成完了")
    }
}

// MockKがRobolectric環境で動作するためのJVMオプション
tasks.withType<Test> {
    jvmArgs("-Djdk.attach.allowAttachSelf=true")
}