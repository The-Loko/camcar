import com.android.build.gradle.LibraryExtension  // add this import

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // ensure app is evaluated last
    project.evaluationDependsOn(":app")
    
    // configure Android library modules (plugins) with a namespace
    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension> {
            // match the plugin's package in its AndroidManifest.xml
            namespace = "com.github.andreociocca.flutter_bluetooth_serial"
            // ensure resources link against API 33 (lStar introduced in API 31)
            compileSdk = 33
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
