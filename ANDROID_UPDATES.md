# Android APK Updates

The Android updater checks the latest published release in `HitzoCain/hydrohub-app`. It offers only a higher Android build number, downloads the release APK into the app's private cache, verifies its SHA-256 checksum, then opens Android's installer for user confirmation. Update checks are optional and do not change Supabase data or schema.

## First Release Setup

The permanent Android application ID is `io.github.hitzocain.aquainlavada`. Do not change it after distributing the first APK.

Create a long-lived signing key from the project root. `keytool` will prompt for the passwords; do not put passwords in the command line:

```powershell
keytool -genkeypair -v -keystore android/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias aqua-in-lavada
Copy-Item android/key.properties.example android/key.properties
```

Edit `android/key.properties` with the passwords you chose. It is ignored by Git. The keystore file is also ignored by Git. Store secure backups of both outside this computer; losing the key prevents future APKs from updating existing installs. Never commit either file or send them to GitHub.

## Publishing an Update

1. Increase the build number after `+` in `pubspec.yaml` for every release, for example `1.0.0+2`.
2. Build the signed APK with `flutter build apk --release`.
3. Calculate the APK checksum:

   ```powershell
   Get-FileHash .\build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
   ```

4. Create `update.json` with the APK's version, build number, filename, and checksum:

   ```json
   {
     "packageName": "io.github.hitzocain.aquainlavada",
     "versionName": "1.0.0",
     "versionCode": 2,
     "apkAssetName": "aqua-in-lavada.apk",
     "sha256": "PASTE_THE_64_CHARACTER_SHA256_HERE",
     "releaseNotes": "Brief description of this update."
   }
   ```

5. Rename the built APK to `aqua-in-lavada.apk`, create a GitHub Release in `HitzoCain/hydrohub-app`, and attach both `aqua-in-lavada.apk` and `update.json`. Publish it as a non-draft, non-prerelease release.
6. Test the update on a separate Android device that has the previous release installed before sharing the release more widely.

The APK and manifest must be assets on the same GitHub Release. Each APK must use this same application ID and the same signing key. Android will show its own installation confirmation. On Android 8 and newer, the user may first need to allow this app to install unknown apps in Settings.

The APK hash detects incomplete or altered downloads. Android's package installer also checks that an update is signed by the same key as the installed app. The updater fails closed if the metadata or hash is invalid.