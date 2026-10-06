import 'package:aqua_in_laba_app/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validHash =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  Map<String, dynamic> manifest({
    String packageName = AppUpdate.packageName,
    int versionCode = 2,
    String sha256 = validHash,
    String apkAssetName = 'aqua-in-lavada.apk',
  }) => {
    'packageName': packageName,
    'versionName': '1.0.1',
    'versionCode': versionCode,
    'apkAssetName': apkAssetName,
    'sha256': sha256,
  };

  List<dynamic> assets({
    String name = 'aqua-in-lavada.apk',
    String url =
        'https://github.com/HitzoCain/hydrohub-app/releases/download/v1.0.1/aqua-in-lavada.apk',
  }) => [
    {'name': name, 'browser_download_url': url, 'size': 1234},
  ];

  test('accepts a newer APK from this GitHub repository', () {
    final update = AppUpdate.fromManifest(
      manifest: manifest(),
      releaseAssets: assets(),
      installedBuildNumber: 1,
    );

    expect(update?.versionName, '1.0.1');
    expect(update?.versionCode, 2);
    expect(update?.apkUri.host, 'github.com');
    expect(update?.sha256, validHash);
  });

  test('does not offer a build that is not newer', () {
    final update = AppUpdate.fromManifest(
      manifest: manifest(versionCode: 1),
      releaseAssets: assets(),
      installedBuildNumber: 1,
    );

    expect(update, isNull);
  });

  test('rejects a manifest for another Android package', () {
    expect(
      () => AppUpdate.fromManifest(
        manifest: manifest(packageName: 'com.example.other'),
        releaseAssets: assets(),
        installedBuildNumber: 1,
      ),
      throwsFormatException,
    );
  });

  test('rejects a non-GitHub APK URL', () {
    expect(
      () => AppUpdate.fromManifest(
        manifest: manifest(),
        releaseAssets: assets(
          url: 'https://attacker.example/aqua-in-lavada.apk',
        ),
        installedBuildNumber: 1,
      ),
      throwsFormatException,
    );
  });

  test('rejects an invalid SHA-256 value', () {
    expect(
      () => AppUpdate.fromManifest(
        manifest: manifest(sha256: 'not-a-checksum'),
        releaseAssets: assets(),
        installedBuildNumber: 1,
      ),
      throwsFormatException,
    );
  });

  test('rejects a missing APK asset', () {
    expect(
      () => AppUpdate.fromManifest(
        manifest: manifest(),
        releaseAssets: assets(name: 'different.apk'),
        installedBuildNumber: 1,
      ),
      throwsFormatException,
    );
  });
}
