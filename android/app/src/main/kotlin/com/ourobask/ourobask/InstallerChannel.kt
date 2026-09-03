package com.ourobask.ourobask

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * ช่องทางฝั่ง Android ของระบบ "อัปเดตในแอป":
 *  - versionName        : เวอร์ชันที่ติดตั้งอยู่จริง (ใช้เทียบกับรีลีสบน GitHub)
 *  - abis               : สถาปัตยกรรมของเครื่อง เพื่อเลือก APK ไฟล์ที่เล็กที่สุดที่ใช้ได้
 *  - canRequestInstalls : Android 8 ขึ้นไปต้องได้สิทธิ์ "ติดตั้งแอปที่ไม่รู้จัก" ก่อน
 *  - openInstallSettings: พาผู้ใช้ไปหน้าตั้งค่าของสิทธิ์นั้น
 *  - install            : ส่งไฟล์ APK ที่ดาวน์โหลดมาให้ตัวติดตั้งของระบบ
 */
class InstallerChannel(private val context: Context) {

    companion object {
        const val CHANNEL = "ourobask/installer"
        private const val APK_MIME = "application/vnd.android.package-archive"
    }

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            handle(call, result)
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "versionName" -> result.success(versionName())
            "abis" -> result.success(Build.SUPPORTED_ABIS.toList())
            "canRequestInstalls" -> result.success(canRequestInstalls())
            "openInstallSettings" -> openInstallSettings(result)
            "install" -> install(call.argument<String>("path"), result)
            else -> result.notImplemented()
        }
    }

    private fun versionName(): String? = try {
        context.packageManager.getPackageInfo(context.packageName, 0).versionName
    } catch (error: Exception) {
        null
    }

    private fun canRequestInstalls(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    private fun openInstallSettings(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(false)
            return
        }
        try {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${context.packageName}"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            result.success(true)
        } catch (error: Exception) {
            result.error("failed", error.message, null)
        }
    }

    private fun install(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrEmpty()) {
            result.error("invalid", "ไม่ได้ระบุไฟล์ติดตั้ง", null)
            return
        }
        val file = File(path)
        if (!file.exists()) {
            result.error("missing", "ไม่พบไฟล์ติดตั้งที่ดาวน์โหลดไว้", null)
            return
        }
        try {
            // ตั้งแต่ Android 7 ส่ง file:// ให้แอปอื่นไม่ได้ ต้องผ่าน FileProvider
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, APK_MIME)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success(true)
        } catch (error: Exception) {
            result.error("failed", error.message, null)
        }
    }
}
