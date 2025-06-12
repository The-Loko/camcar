// Set compile and target SDK early for all modules (applied before plugin evaluation)
extra.set("compileSdkVersion", 35)
extra.set("targetSdkVersion", 35)

import com.android.build.gradle.LibraryExtension  // add this import
import com.android.build.api.dsl.ApplicationExtension  // to configure application modules
import com.android.build.gradle.AppExtension
import org.gradle.api.file.Directory
import org.gradle.api.tasks.Delete

// Override compileSdk for application and library plugins as soon as they are applied
import com.android.build.gradle.LibraryExtension
import com.android.build.gradle.AppPlugin
import com.android.build.gradle.AppExtension

pluginsManagement {
    // ensure overrides apply on plugin application
}
pluginManager.withPlugin("com.android.application") {
    extensions.configure<AppExtension> {
        compileSdkVersion(35)
    }
}
pluginManager.withPlugin("com.android.library") {
    extensions.configure<LibraryExtension> {
        compileSdk = 35
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Apply compileSdk overrides before any subprojects are evaluated
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileSdk = 35
        }
    }
    pluginManager.withPlugin("com.android.application") {
        extensions.configure<com.android.build.gradle.AppExtension> {
            compileSdkVersion(35)
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
      // ensure app is evaluated last
    project.evaluationDependsOn(":app")
    
    // Force all Android library modules to use API 35
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<LibraryExtension> {
            compileSdk = 35
            namespace = when (project.name) {
                "flutter_bluetooth_serial" -> "io.github.edufolly.flutterbluetoothserial"
                else -> namespace ?: "io.github.edufolly.flutterbluetoothserial"
            }
        }
    }
    // Also force Android app modules to use API 35 (plugin modules sometimes use application plugin)
    pluginManager.withPlugin("com.android.application") {
        extensions.configure<ApplicationExtension> {
            compileSdk = 35
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
