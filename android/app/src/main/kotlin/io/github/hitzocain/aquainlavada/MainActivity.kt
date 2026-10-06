package io.github.hitzocain.aquainlavada

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
	private val updateChannelName = "io.github.hitzocain.aquainlavada/app_installer"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"canInstallPackages" -> {
						result.success(
							Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
								packageManager.canRequestPackageInstalls(),
						)
					}
					"openInstallPermissionSettings" -> {
						try {
							val intent = Intent(
								Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
								Uri.parse("package:$packageName"),
							)
							startActivity(intent)
							result.success(null)
						} catch (error: Exception) {
							result.error("SETTINGS_UNAVAILABLE", error.message, null)
						}
					}
					"installApk" -> installApk(call.argument<String>("path"), result)
					else -> result.notImplemented()
				}
			}
	}

	private fun installApk(path: String?, result: MethodChannel.Result) {
		if (path == null) {
			result.error("INVALID_APK", "APK path is missing.", null)
			return
		}

		try {
			val updateDirectory = File(cacheDir, "updates").canonicalFile
			val apkFile = File(path).canonicalFile
			if (apkFile.parentFile != updateDirectory || !apkFile.isFile || apkFile.length() == 0L) {
				result.error("INVALID_APK", "Verified APK file is unavailable.", null)
				return
			}

			val apkUri = FileProvider.getUriForFile(
				this,
				"$packageName.fileprovider",
				apkFile,
			)
			val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
				setDataAndType(apkUri, "application/vnd.android.package-archive")
				addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
			}
			startActivity(intent)
			result.success(null)
		} catch (error: Exception) {
			result.error("INSTALLER_UNAVAILABLE", error.message, null)
		}
	}
}