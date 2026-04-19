#!/bin/bash
# Melody Flow — Fix Kotlin DSL signing config
# The previous script wrote Groovy syntax into a Kotlin DSL file.
# This script writes a correct android/app/build.gradle.kts from scratch.
#
# Run from project root:
#   bash fix_gradle_kts.sh

set -e

echo "🔧 Fixing android/app/build.gradle.kts signing config (Kotlin DSL)..."
echo ""

if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Run from inside the melody_flow folder."
  exit 1
fi

# ----------------------------------------------------------------------------
# Confirm we're dealing with Kotlin DSL
# ----------------------------------------------------------------------------
if [ ! -f "android/app/build.gradle.kts" ]; then
  echo "❌ android/app/build.gradle.kts not found."
  echo "   Something is unusual — tell me and I'll adapt."
  exit 1
fi

echo "✅ [1/3] Backing up existing build.gradle.kts"
cp android/app/build.gradle.kts android/app/build.gradle.kts.bak

# ----------------------------------------------------------------------------
# Also remove the old Groovy build.gradle if it still exists (conflict source)
# ----------------------------------------------------------------------------
if [ -f "android/app/build.gradle" ]; then
  echo "   Removing stale Groovy build.gradle (keeps .kts as source of truth)"
  rm android/app/build.gradle
fi

# ----------------------------------------------------------------------------
# Write a clean, working build.gradle.kts with Kotlin DSL signing
# ----------------------------------------------------------------------------
echo "✅ [2/3] Writing corrected build.gradle.kts"

cat > android/app/build.gradle.kts << 'EOF'
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin must be applied after Android & Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

// ---- Load keystore properties if they exist ----
// Used by signingConfigs.release. If key.properties is missing (e.g. a fresh
// clone without secrets), the release build gracefully falls back to the
// debug keystore (unusable for Play Store but won't crash local dev).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("app/key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.melodyflow.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        applicationId = "com.melodyflow.app"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val storePath = keystoreProperties["storeFile"] as String
                storeFile = if (storePath.startsWith("/") || storePath.contains(":")) {
                    file(storePath)
                } else {
                    file("${projectDir}/${storePath}")
                }
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Use the release signing config when key.properties is present,
            // otherwise fall back to debug so flutter run still works locally.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("com.google.android.play:core:1.10.3")
    implementation("com.google.android.play:core-ktx:1.8.1")
}
EOF

echo "   ✓ build.gradle.kts rewritten with correct Kotlin DSL"

# ----------------------------------------------------------------------------
# The workflow's "Create key.properties" step writes storeFile=melody-release.jks
# which is a bare filename. Our signingConfigs.release resolves it relative to
# projectDir (android/app/), and the workflow puts the decoded keystore in
# android/app/melody-release.jks — so it all lines up.
# ----------------------------------------------------------------------------

echo "✅ [3/3] Verifying..."
echo ""
echo "---- build.gradle.kts signing section ----"
grep -n "signingConfig" android/app/build.gradle.kts
echo ""

git add -A
git status --short
echo ""

git commit -m "Fix: rewrite android/app/build.gradle.kts with correct Kotlin DSL signing"
git push

echo ""
echo "🎉 Pushed. CI re-running now."
echo "   Watch: https://github.com/dakshu007/melody_flow/actions"
echo ""
echo "   Both jobs should now pass:"
echo "     ✓ build-debug   → unsigned APK"
echo "     ✓ build-release → signed APK + AAB in Artifacts"
