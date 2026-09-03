package com.ourobask.ourobask

import android.app.Activity
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * ช่องทางเสริมฝั่ง Android สำหรับ "เลือกเสียงปลุกจากเครื่องผู้ใช้":
 *  - pickRingtone : เปิดตัวเลือกเสียงของระบบ (เสียงเรียกเข้า/เตือน/ปลุก ที่มีในเครื่อง)
 *  - contentUriFor: แปลงไฟล์เสียงที่ผู้ใช้เลือกเองให้เป็น content:// ที่ระบบอ่านได้
 *  - preview/stop : ลองฟังเสียงด้วย AudioAttributes แบบเดียวกับตอนปลุกจริง
 */
class MainActivity : FlutterActivity() {

    private val channelName = "ourobask/sound"
    private val ringtoneRequestCode = 7411

    private var pendingResult: MethodChannel.Result? = null
    private var previewRingtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handle(call, result) }
        // ระบบตรวจสอบรีลีสและติดตั้งอัปเดตในแอป
        InstallerChannel(applicationContext).attach(flutterEngine.dartExecutor.binaryMessenger)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickRingtone" -> pickRingtone(call.argument<String>("currentUri"), result)
            "titleOf" -> result.success(titleOf(call.argument<String>("uri")))
            "contentUriFor" -> contentUriFor(call.argument<String>("path"), result)
            "preview" -> preview(call.argument<String>("uri"), result)
            "stopPreview" -> {
                stopPreview()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun pickRingtone(currentUri: String?, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "มีการเลือกเสียงค้างอยู่", null)
            return
        }
        pendingResult = result
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALL)
            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "เลือกเสียงปลุก")
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            if (!currentUri.isNullOrEmpty()) {
                putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(currentUri))
            }
        }
        try {
            startActivityForResult(intent, ringtoneRequestCode)
        } catch (error: Exception) {
            pendingResult = null
            result.error("unavailable", "เครื่องนี้ไม่มีตัวเลือกเสียงของระบบ", null)
        }
    }

    // ใช้ startActivityForResult เพราะเป็นวิธีมาตรฐานของตัวเลือกเสียงระบบ
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != ringtoneRequestCode) return
        val result = pendingResult ?: return
        pendingResult = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(null)
            return
        }
        val uri: Uri? = data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        if (uri == null) {
            result.success(null)
            return
        }
        result.success(mapOf("uri" to uri.toString(), "name" to (titleOf(uri.toString()) ?: "เสียงที่เลือก")))
    }

    private fun titleOf(uri: String?): String? {
        if (uri.isNullOrEmpty()) return null
        return try {
            RingtoneManager.getRingtone(applicationContext, Uri.parse(uri))?.getTitle(applicationContext)
        } catch (error: Exception) {
            null
        }
    }

    /**
     * ไฟล์ที่ผู้ใช้เลือกเองถูกคัดลอกไว้ในโฟลเดอร์ของแอป ระบบแจ้งเตือนจึงอ่าน file:// ไม่ได้
     * จึงต้องแปลงเป็น content:// ผ่าน FileProvider แล้วให้สิทธิ์อ่านแก่ระบบ
     */
    private fun contentUriFor(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrEmpty()) {
            result.error("invalid", "ไม่พบไฟล์เสียง", null)
            return
        }
        try {
            val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", File(path))
            for (target in listOf("com.android.systemui", "android", packageName)) {
                grantUriPermission(target, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("failed", error.message, null)
        }
    }

    private fun preview(uri: String?, result: MethodChannel.Result) {
        stopPreview()
        if (uri.isNullOrEmpty()) {
            result.success(false)
            return
        }
        try {
            val ringtone = RingtoneManager.getRingtone(applicationContext, Uri.parse(uri))
            ringtone.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            ringtone.play()
            previewRingtone = ringtone
            result.success(true)
        } catch (error: Exception) {
            result.success(false)
        }
    }

    private fun stopPreview() {
        previewRingtone?.let { if (it.isPlaying) it.stop() }
        previewRingtone = null
    }

    override fun onPause() {
        stopPreview()
        super.onPause()
    }
}
