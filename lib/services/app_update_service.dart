import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdate {
  const AppUpdate({
    required this.versionName,
    required this.versionCode,
    required this.apkUri,
    required this.apkSize,
    required this.sha256,
    required this.releaseNotes,
  });

  final String versionName;
  final int versionCode;
  final Uri apkUri;
  final int apkSize;
  final String sha256;
  final String releaseNotes;

  static const packageName = 'io.github.hitzocain.aquainlavada';
  static const _releaseAssetPrefix =
      '/HitzoCain/hydrohub-app/releases/download/';
  static const _maxApkSize = 300 * 1024 * 1024;

  static AppUpdate? fromManifest({
    required Map<String, dynamic> manifest,
    required List<dynamic> releaseAssets,
    required int installedBuildNumber,
  }) {
    if (manifest['packageName'] != packageName) {
      throw const FormatException('Update package name does not match.');
    }

    final versionName = manifest['versionName'];
    final versionCode = manifest['versionCode'];
    final apkName = manifest['apkAssetName'];
    final expectedHash = manifest['sha256'];
    if (versionName is! String || versionName.trim().isEmpty) {
      throw const FormatException('Update version name is missing.');
    }
    if (versionCode is! int || versionCode <= installedBuildNumber) {
      return null;
    }
    if (apkName is! String ||
        !RegExp(r'^[a-zA-Z0-9._-]+\.apk$').hasMatch(apkName)) {
      throw const FormatException('Update APK name is invalid.');
    }
    if (expectedHash is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(expectedHash)) {
      throw const FormatException('Update checksum is invalid.');
    }

    final matchingAssets = releaseAssets
        .whereType<Map<String, dynamic>>()
        .where((asset) => asset['name'] == apkName);
    if (matchingAssets.length != 1) {
      throw const FormatException('Update APK asset is missing or ambiguous.');
    }
    final asset = matchingAssets.single;
    final downloadUrl = asset['browser_download_url'];
    final size = asset['size'];
    if (downloadUrl is! String ||
        size is! int ||
        size <= 0 ||
        size > _maxApkSize) {
      throw const FormatException('Update APK asset details are invalid.');
    }

    final apkUri = Uri.tryParse(downloadUrl);
    if (apkUri == null ||
        apkUri.scheme != 'https' ||
        apkUri.host != 'github.com' ||
        !apkUri.path.startsWith(_releaseAssetPrefix)) {
      throw const FormatException('Update APK URL is not trusted.');
    }

    return AppUpdate(
      versionName: versionName.trim(),
      versionCode: versionCode,
      apkUri: apkUri,
      apkSize: size,
      sha256: expectedHash.toLowerCase(),
      releaseNotes: (manifest['releaseNotes'] as String? ?? '').trim(),
    );
  }
}

class AppUpdateService {
  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  static const _installerChannel = MethodChannel(
    'io.github.hitzocain.aquainlavada/app_installer',
  );
  static const _lastCheckKey = 'app_update_last_check_ms';
  static const _checkInterval = Duration(hours: 6);
  static final _latestReleaseUri = Uri.https(
    'api.github.com',
    '/repos/HitzoCain/hydrohub-app/releases/latest',
  );

  final http.Client _client;

  Future<AppUpdate?> checkForUpdate() async {
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastCheck = preferences.getInt(_lastCheckKey);
    if (lastCheck != null) {
      final elapsed = now.difference(
        DateTime.fromMillisecondsSinceEpoch(lastCheck),
      );
      if (!elapsed.isNegative && elapsed < _checkInterval) return null;
    }
    await preferences.setInt(_lastCheckKey, now.millisecondsSinceEpoch);

    return _fetchLatestUpdate();
  }

  Future<AppUpdate?> _fetchLatestUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final installedBuildNumber = int.tryParse(packageInfo.buildNumber);
    if (installedBuildNumber == null) {
      throw const FormatException('Installed build number is invalid.');
    }

    final releaseResponse = await _client
        .get(_latestReleaseUri, headers: _githubHeaders)
        .timeout(const Duration(seconds: 12));
    if (releaseResponse.statusCode == 404) return null;
    if (releaseResponse.statusCode != 200) {
      throw HttpException(
        'GitHub release check failed (${releaseResponse.statusCode}).',
      );
    }

    final release = jsonDecode(releaseResponse.body);
    if (release is! Map<String, dynamic> || release['draft'] == true) {
      return null;
    }
    final assets = release['assets'];
    if (assets is! List) return null;
    final manifestAssets = assets.whereType<Map<String, dynamic>>().where(
      (asset) => asset['name'] == 'update.json',
    );
    if (manifestAssets.length != 1) return null;

    final manifestUri = _trustedReleaseUri(
      manifestAssets.single['browser_download_url'],
    );
    if (manifestUri == null) return null;
    final manifestResponse = await _client
        .get(manifestUri, headers: _githubHeaders)
        .timeout(const Duration(seconds: 12));
    if (manifestResponse.statusCode != 200) {
      throw HttpException(
        'Update manifest download failed (${manifestResponse.statusCode}).',
      );
    }
    final manifest = jsonDecode(manifestResponse.body);
    if (manifest is! Map<String, dynamic>) {
      throw const FormatException('Update manifest is invalid.');
    }

    return AppUpdate.fromManifest(
      manifest: manifest,
      releaseAssets: assets,
      installedBuildNumber: installedBuildNumber,
    );
  }

  Future<File> downloadAndVerify(
    AppUpdate update, {
    required void Function(int received, int total) onProgress,
  }) async {
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}updates',
    );
    await directory.create(recursive: true);
    final partialFile = File(
      '${directory.path}${Platform.pathSeparator}update-${update.versionCode}.part',
    );
    final apkFile = File(
      '${directory.path}${Platform.pathSeparator}update-${update.versionCode}.apk',
    );
    if (await partialFile.exists()) await partialFile.delete();
    if (await apkFile.exists()) await apkFile.delete();

    final request = http.Request('GET', update.apkUri)
      ..headers.addAll(_githubHeaders);
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw HttpException('APK download failed (${response.statusCode}).');
    }

    final output = partialFile.openWrite();
    final checksumSink = _SingleDigestSink();
    final checksumInput = sha256.startChunkedConversion(checksumSink);
    var received = 0;
    var outputClosed = false;
    try {
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        received += chunk.length;
        if (received > update.apkSize || received > AppUpdate._maxApkSize) {
          throw const FormatException(
            'Downloaded APK exceeds its declared size.',
          );
        }
        output.add(chunk);
        checksumInput.add(chunk);
        onProgress(received, update.apkSize);
      }
      await output.flush();
      await output.close();
      outputClosed = true;
      checksumInput.close();

      if (received != update.apkSize ||
          checksumSink.digest.toString() != update.sha256) {
        throw const FormatException('Downloaded APK failed verification.');
      }
      return await partialFile.rename(apkFile.path);
    } catch (_) {
      if (!outputClosed) await output.close();
      if (await partialFile.exists()) await partialFile.delete();
      rethrow;
    }
  }

  Future<bool> canInstallPackages() async =>
      await _installerChannel.invokeMethod<bool>('canInstallPackages') ?? false;

  Future<void> openInstallPermissionSettings() =>
      _installerChannel.invokeMethod<void>('openInstallPermissionSettings');

  Future<void> installApk(File apkFile) => _installerChannel.invokeMethod<void>(
    'installApk',
    {'path': apkFile.path},
  );

  static Uri? _trustedReleaseUri(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        !uri.path.startsWith(AppUpdate._releaseAssetPrefix)) {
      return null;
    }
    return uri;
  }

  static const _githubHeaders = {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'AquaInLavadaUpdater',
  };
}

class _SingleDigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest value) => digest = value;

  @override
  void close() {}
}
