plugins { id("com.android.library") }
android {
    namespace = "nl.taima.room"; compileSdk { version = release(37) { minorApiLevel = 2 } }
    defaultConfig { minSdk = 28; javaCompileOptions.annotationProcessorOptions.arguments["room.schemaLocation"] = "$projectDir/schemas" }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_21; targetCompatibility = JavaVersion.VERSION_21 }
}
// Instrumentation uses the app's Room runtime, selected by WorkManager.
// Keep generated benchmark code compatible with that runtime.
dependencies { api("androidx.room:room-runtime:2.6.1"); annotationProcessor("androidx.room:room-compiler:2.6.1") }
