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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugins pin older Android/Kotlin Gradle plugins in their own buildscript (printing ->
// AGP 7.3.0, Kotlin 2.2.10). The app's versions are the ones that actually builds them, so map those requests onto it instead
// of downloading old copies (which also fails behind TLS-intercepting networks).
subprojects {
    buildscript {
        configurations.configureEach {
            resolutionStrategy.eachDependency {
                if (requested.group == "com.android.tools.build" && requested.name == "gradle") {
                    useVersion("9.0.1")
                    because("use the app's Android Gradle plugin")
                }
                if (requested.group == "org.jetbrains.kotlin" && requested.name.startsWith("kotlin-gradle-plugin")) {
                    useVersion("2.3.20")
                    because("use the app's Kotlin Gradle plugin")
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
