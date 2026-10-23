package com.mehmetkarataslar.arsivim

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.PackageInfo
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "arsivim/app_update")
            .setMethodCallHandler { call, result ->
                if (call.method != "installApk") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val path = call.argument<String>("path") ?: error("Paket yolu bulunamadı.")
                    val file = File(path).canonicalFile
                    val root = File(cacheDir, "arsivim-updates").canonicalFile
                    require(file.path.startsWith(root.path + File.separator) &&
                        file.isFile && file.extension == "apk") { "Güncelleme dosyası geçersiz." }
                    verifyUpdate(file)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !packageManager.canRequestPackageInstalls()) {
                        startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName")))
                        result.success("permissionRequired")
                    } else {
                        val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
                        startActivity(Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        })
                        result.success("opened")
                    }
                } catch (e: Exception) {
                    result.error("UPDATE_INSTALL_FAILED", e.message ?: "Kurulum açılamadı.", null)
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun verifyUpdate(file: File) {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val candidate = packageManager.getPackageArchiveInfo(file.path, flags)
            ?: error("APK okunamadı. Yeniden indirin.")
        val installed = packageManager.getPackageInfo(packageName, flags)
        require(candidate.packageName == packageName) { "Paket bu uygulamaya ait değil." }
        val candidateCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            candidate.longVersionCode else candidate.versionCode.toLong()
        val installedCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            installed.longVersionCode else installed.versionCode.toLong()
        require(candidateCode > installedCode) { "Paket yüklü sürümden daha yeni değil." }
        fun signatures(info: PackageInfo): Set<String> {
            val signers = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
                info.signingInfo?.apkContentsSigners else info.signatures
            return signers?.map { it.toCharsString() }?.toSet() ?: emptySet()
        }
        val trusted = signatures(installed)
        require(trusted.isNotEmpty() && signatures(candidate) == trusted) {
            "Güncellemenin imzası yüklü uygulamayla eşleşmiyor."
        }
    }
}
