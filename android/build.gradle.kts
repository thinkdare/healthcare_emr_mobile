allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some Flutter plugins (e.g. flutter_jailbreak_detection 1.10.0) predate
// AGP 8's mandatory `namespace` property and only declare their package via
// the legacy AndroidManifest.xml `package` attribute, which AGP 8 no longer
// reads. Back-fill namespace from that attribute for any subproject missing
// one, instead of patching each outdated plugin individually.
subprojects {
    afterEvaluate {
        val androidExtension = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        if (androidExtension != null && androidExtension.namespace == null) {
            val manifestFile = file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val packageName = Regex("package=\"([^\"]+)\"")
                    .find(manifestFile.readText())
                    ?.groupValues
                    ?.get(1)
                if (packageName != null) {
                    androidExtension.namespace = packageName
                }
            }
        }
    }

    // Same vintage of plugin leaves Java/Kotlin compile targets unset, which
    // now default to mismatched JVM versions (javac 1.8 vs Kotlin's JDK-21
    // default) and fail the build. Align both to the app module's own
    // Java 17 target (android/app/build.gradle.kts) for every subproject.
    plugins.withId("org.jetbrains.kotlin.android") {
        extensions.configure<com.android.build.gradle.BaseExtension> {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
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
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
