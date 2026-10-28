plugins { id("com.android.library") }
android {
    namespace = "nl.taima.room"; compileSdk { version = release(37) { minorApiLevel = 2 } }
    defaultConfig { minSdk = 28; javaCompileOptions.annotationProcessorOptions.arguments["room.schemaLocation"] = "$projectDir/schemas" }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_21; targetCompatibility = JavaVersion.VERSION_21 }
}
dependencies { api("androidx.room:room-runtime:2.8.5"); annotationProcessor("androidx.room:room-compiler:2.8.5") }
