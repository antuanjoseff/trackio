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

// 🌟 INYECCIÓN DE NAMESPACE DIRECTA Y FORZADA PARA ISAR (MÓDULO LIMPIO)
subprojects {
    afterEvaluate {
        if (project.name == "isar_flutter_libs") {
            val androidExtension = project.extensions.findByName("android")
            if (androidExtension != null) {
                // Forzamos el namespace mediante reflexión de Gradle para evitar errores de tipado en Kotlin DSL
                val dNamespace = androidExtension.javaClass.getMethod("setNamespace", String::class.java)
                dNamespace.invoke(androidExtension, "dev.isar.isar_flutter_libs")
            }
        }
    }
}

subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.application") || plugins.hasPlugin("com.android.library")) {
            configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion(36)
                ndkVersion = "28.1.13356709"
            }
        }
    }
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
