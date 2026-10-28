plugins { id("com.android.application"); id("org.jetbrains.kotlin.plugin.compose") }
android {
    namespace = "nl.taima"
    compileSdk { version = release(37) { minorApiLevel = 2 } }
    buildToolsVersion = "36.0.0"
    defaultConfig { applicationId = "nl.taima.android"; minSdk = 28; targetSdk = 36; versionCode = 1; versionName = "0.1-trial"; testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner" }
    buildFeatures { compose = true }
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
    buildTypes { release { isMinifyEnabled = true; proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt")); signingConfig = signingConfigs.getByName("localRelease") } }
    sourceSets.getByName("main").assets.srcDir("../../Packages/TaimaCore/Sources/TaimaCore/Resources")
    sourceSets.getByName("androidTest").assets.srcDir("../../contracts/golden")
    if (providers.gradleProperty("withSwift").orNull == "true") { sourceSets.getByName("main").jniLibs.srcDir("generated-jni") }
    if (providers.gradleProperty("withGenerated").orNull == "true") {
        sourceSets.getByName("main").java.srcDirs("../swiftjava/java", "../swiftjava/runtime")
        sourceSets.getByName("androidTest").java.srcDir("src/generatedTest/java")
    }
    packaging { jniLibs.useLegacyPackaging = true }
}
dependencies {
    implementation(project(":core"))
    implementation(platform("androidx.compose:compose-bom:2026.09.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.10.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation(project(":storage-room"))
}
