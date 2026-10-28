plugins { id("com.android.application"); id("org.jetbrains.kotlin.plugin.compose") }
val projectSpec = rootProject.file("../project.yml").readText()
val taimaVersion = Regex("MARKETING_VERSION: \"([^\"]+)\"").find(projectSpec)!!.groupValues[1]
val taimaBuild = Regex("CURRENT_PROJECT_VERSION: \"([^\"]+)\"").find(projectSpec)!!.groupValues[1].toInt()

android {
    namespace = "nl.taima"
    compileSdk { version = release(37) { minorApiLevel = 2 } }
    buildToolsVersion = "36.0.0"
    defaultConfig { applicationId = "nl.taima.android"; minSdk = 28; targetSdk = 36; versionCode = taimaBuild; versionName = taimaVersion; testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner" }
    buildFeatures { compose = true; buildConfig = true }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_21; targetCompatibility = JavaVersion.VERSION_21 }
    signingConfigs {
        create("localRelease") {
            val path = providers.environmentVariable("TAIMA_KEYSTORE").orNull
            if (path != null) {
                storeFile = file(path); storePassword = providers.environmentVariable("TAIMA_STORE_PASSWORD").orNull
                keyAlias = "taima-trial"; keyPassword = providers.environmentVariable("TAIMA_KEY_PASSWORD").orNull
            }
        }
    }
    buildTypes { release { isMinifyEnabled = true; proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"); signingConfig = signingConfigs.getByName("localRelease") } }
    sourceSets.getByName("main").assets.srcDir("../../Packages/TaimaCore/Sources/TaimaCore/Resources")
    sourceSets.getByName("androidTest").assets.srcDir("../../contracts/golden")
    sourceSets.getByName("main").jniLibs.srcDir("generated-jni")
    sourceSets.getByName("main").assets.srcDir("../../App/Taima/Resources")
    if (providers.gradleProperty("withGenerated").orNull == "true") {
        sourceSets.getByName("main").java.srcDirs("../swiftjava/java", "../swiftjava/runtime")
        sourceSets.getByName("androidTest").java.srcDir("src/generatedTest/java")
    }
    packaging { jniLibs.useLegacyPackaging = true }
}
dependencies {
    implementation("com.google.code.gson:gson:2.13.2")
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.work:work-runtime-ktx:2.10.5")
    implementation("androidx.documentfile:documentfile:1.1.0")
    implementation("cz.adaptech.tesseract4android:tesseract4android:4.9.0")
    implementation(platform("androidx.compose:compose-bom:2026.09.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.10.0")
    androidTestImplementation(project(":core"))
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation(project(":storage-room"))
}
