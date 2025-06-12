import com.android.build.gradle.LibraryExtension  // add this import
import org.gradle.api.file.Directory
import org.gradle.api.tasks.Delete

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
    
    // Force all Android library modules to use API 35 (needed for lStar)
    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension> {
            // Bump to 35 to satisfy plugin requirements and lStar attribute
            compileSdk = 35
            namespace = when (project.name) {
                "flutter_bluetooth_serial" -> "io.github.edufolly.flutterbluetoothserial"
                else -> namespace ?: "io.github.edufolly.flutterbluetoothserial"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
