import java.util.Properties
import java.io.FileInputStream

// Chave de assinatura do release, quando ela existir.
//
// O arquivo NAO vai para o repositorio (ver .gitignore), e a keystore mora
// fora dele. Quem clonar o projeto sem a chave continua conseguindo compilar:
// o release cai na chave de debug, exatamente como era antes -- serve para
// instalar no proprio aparelho, e nao para distribuir.
val chaveDoRelease = Properties()
val arquivoDaChave = rootProject.file("key.properties")
if (arquivoDaChave.exists()) {
    chaveDoRelease.load(FileInputStream(arquivoDaChave))
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Precisa vir DEPOIS do plugin do Android: ele le a configuracao do modulo
    // para saber onde procurar o google-services.json.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.devlingo.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identidade do app na Play Store. E imutavel na pratica: mudar depois de
        // publicar quebra a atualizacao para quem ja instalou. Mesma natureza do
        // campo id das questoes.
        applicationId = "com.devlingo.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Sem key.properties estes campos ficam nulos, e o bloco abaixo
            // nao usa esta configuracao. E o caso de quem clonou o projeto.
            keyAlias = chaveDoRelease.getProperty("keyAlias")
            keyPassword = chaveDoRelease.getProperty("keyPassword")
            storeFile = chaveDoRelease.getProperty("storeFile")?.let { file(it) }
            storePassword = chaveDoRelease.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            // Assina com a chave de verdade quando ela esta disponivel, e cai
            // na de debug quando nao esta.
            //
            // Cair na de debug e deliberado, e nao descuido: sem isso, quem
            // clonasse o repositorio nao conseguiria nem compilar um release
            // para o proprio celular. O preco e que um APK assim NAO serve
            // para distribuir -- e a diferenca aparece em `apksigner verify`,
            // que mostra o dono do certificado.
            signingConfig = if (arquivoDaChave.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
