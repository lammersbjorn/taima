# Keep JNI names and Glance callbacks referenced by framework-created components.
-keep class nl.taima.NativeBridge { *; }
-keep class nl.taima.QuickLog { public <init>(); }
# Room creates generated databases, including WorkManager's, by reflection.
-keepclassmembers class * extends androidx.room.RoomDatabase { public <init>(); }
