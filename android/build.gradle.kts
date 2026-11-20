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
    // kotlin-android on AGP 9) compile their .kt sources when android.builtInKotlin=false,
    // and ensure legacy library plugins (e.g., flutter_native_splash on SDK 31) compile against SDK 36+.
    pluginManager.withPlugin("com.android.library") {
        val srcMain = file("src/main")
        val hasKotlinSources = srcMain.exists() && srcMain.walkTopDown().any { it.isFile && it.extension == "kt" }
        if (hasKotlinSources && !pluginManager.hasPlugin("org.jetbrains.kotlin.android")) {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }
        afterEvaluate {
            val androidExt = extensions.findByName("android") ?: return@afterEvaluate
            val currentSdk = runCatching {
                androidExt.javaClass.getMethod("getCompileSdk").invoke(androidExt) as? Int
            }.getOrNull() ?: 0
            if (currentSdk < 36) {
                runCatching {
                    androidExt.javaClass.getMethod("setCompileSdk", Integer::class.java).invoke(androidExt, 36)
                }.onFailure {
                    runCatching {
                        androidExt.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType).invoke(androidExt, 36)
                    }
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
