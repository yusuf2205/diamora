package uz.diamoraa.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

/**
 * Self-update (the app is installed from diamoraa.uz, not from Google Play): Dart downloads the new APK in the
 * background into cacheDir/updates; this channel verifies it and hands it to the system installer. Android always
 * asks the person to confirm the install - that single tap is the one thing an app outside the Play Store cannot skip.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "diamoraa/updater").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "info" -> {
                        val pi = packageManager.getPackageInfo(packageName, 0)
                        @Suppress("DEPRECATION")
                        val code = if (Build.VERSION.SDK_INT >= 28) pi.longVersionCode else pi.versionCode.toLong()
                        result.success(mapOf(
                            "versionCode" to code,
                            "is64" to Build.SUPPORTED_64_BIT_ABIS.isNotEmpty(),
                            "dir" to File(cacheDir, "updates").apply { mkdirs() }.absolutePath,
                        ))
                    }
                    "sha256" -> {
                        val f = File(call.argument<String>("path")!!)
                        if (!f.exists()) { result.success(null); return@setMethodCallHandler }
                        val md = MessageDigest.getInstance("SHA-256")
                        f.inputStream().use { input ->
                            val buf = ByteArray(1 shl 16)
                            while (true) { val n = input.read(buf); if (n < 0) break; md.update(buf, 0, n) }
                        }
                        result.success(md.digest().joinToString("") { "%02x".format(it) })
                    }
                    "canInstall" -> result.success(Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls())
                    "openInstallSettings" -> {
                        startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                        result.success(true)
                    }
                    "install" -> {
                        val f = File(call.argument<String>("path")!!)
                        val uri = FileProvider.getUriForFile(this, "$packageName.updates", f)
                        startActivity(Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        })
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("UPDATER", e.message, null)
            }
        }
    }
}
