allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Ensure Kotlin-based plugins (e.g., FlutterFire plugins that skip applying
    // kotlin-android on AGP 9) compile their .kt sources when android.builtInKotlin=false.
    pluginManager.withPlugin("com.android.library") {
        val srcMain = file("src/main")
        val hasKotlinSources = srcMain.exists() && srcMain.walkTopDown().any { it.isFile && it.extension == "kt" }
        if (hasKotlinSources && !pluginManager.hasPlugin("org.jetbrains.kotlin.android")) {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
