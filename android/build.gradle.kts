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

subprojects {
    project.plugins.whenPluginAdded {
        if (this.javaClass.name.contains("com.android.build.gradle.LibraryPlugin") ||
            this.javaClass.name.contains("com.android.build.gradle.AppPlugin")) {
            val android = project.extensions.getByName("android")
            try {
                val method = android.javaClass.getMethod("setNamespace", String::class.java)
                method.invoke(android, project.group.toString().takeIf { it.isNotEmpty() && it != "unspecified" } ?: "io.flutter.plugins.${project.name}")
            } catch (e: Exception) {
                // Method might not exist or other issue
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
