plugins { kotlin("jvm") }
kotlin { jvmToolchain(21) }
dependencies {
    api("com.google.code.gson:gson:2.13.2")
    testImplementation("junit:junit:4.13.2")
}
tasks.test {
    systemProperty("taima.goldens", rootProject.file("../contracts/golden").absolutePath)
    val trialLocale = providers.gradleProperty("trialLocale").getOrElse("en_US").split("_")
    systemProperty("user.language", trialLocale[0])
    systemProperty("user.country", trialLocale[1])
    systemProperty("user.timezone", "Europe/Amsterdam")
    testLogging { events("passed", "failed", "skipped"); showStandardStreams = true }
}
