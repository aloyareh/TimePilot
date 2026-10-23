package com.example.time_pilot

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ContentValues
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.activity.result.contract.ActivityResultContracts

/**
 * Manifest memberi showWhenLocked/turnScreenOn supaya alarm bisa menyalakan layar
 * dan tampil di atas layar kunci. Agar app tidak "menempel" di atas layar kunci
 * pada pemakaian biasa:
 *  - alarmMode = true bila aktivitas dibuka saat HP terkunci (alarm).
 *  - Saat layar mati di luar alarmMode, flag showWhenLocked/turnScreenOn dimatikan
 *    sementara: layar kunci muncul normal dan setelah dibuka kunci pengguna kembali
 *    ke app yang tadi terbuka. Flag dinyalakan lagi saat alarm datang (onNewIntent).
 *  - Setelah tantangan alarm selesai, Dart memanggil "leave": minta buka kunci;
 *    bila dibatalkan, task disembunyikan di belakang layar kunci.
 */
class MainActivity : FlutterFragmentActivity() {
    private var alarmMode = false

    private var pendingPick: MethodChannel.Result? = null
    private var preview: Ringtone? = null
    private val previewHandler = Handler(Looper.getMainLooper())
 
    private val pickAudio =
        registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
            val res = pendingPick
            pendingPick = null
            if (res == null) return@registerForActivityResult
            if (uri == null) {
                res.success(null)
                return@registerForActivityResult
            }
            Thread {
                try {
                    val out = importToMediaStore(uri)
                    runOnUiThread { res.success(out) }
                } catch (e: Exception) {
                    runOnUiThread { res.error("IMPORT_FAILED", e.message ?: "Gagal mengimpor suara.", null) }
                }
            }.start()
        }
 
    private fun importToMediaStore(src: Uri): Map<String, String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw IllegalStateException("Impor suara butuh Android 10 atau lebih baru.")
        }
        val cr = contentResolver
        val mime = cr.getType(src) ?: "audio/mpeg"
        if (!mime.startsWith("audio/")) throw IllegalArgumentException("File yang dipilih bukan audio.")
        var name = "alarm"
        var size = 0L
        cr.query(src, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                name = c.getString(0) ?: name
                size = c.getLong(1)
            }
        }
        if (size > 10L * 1024 * 1024) throw IllegalArgumentException("File terlalu besar (maksimal 10 MB).")
 
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, "TimePilot_${System.currentTimeMillis()}_$name")
            put(MediaStore.Audio.Media.MIME_TYPE, mime)
            put(MediaStore.Audio.Media.RELATIVE_PATH, Environment.DIRECTORY_ALARMS + "/TimePilot")
            put(MediaStore.Audio.Media.IS_ALARM, 1)
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }
        val dest = cr.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Tidak bisa menyimpan suara.")
        try {
            cr.openInputStream(src)!!.use { input ->
                cr.openOutputStream(dest)!!.use { output -> input.copyTo(output) }
            }
            val done = ContentValues().apply { put(MediaStore.Audio.Media.IS_PENDING, 0) }
            cr.update(dest, done, null, null)
        } catch (e: Exception) {
            cr.delete(dest, null, null)
            throw e
        }
        return mapOf("uri" to dest.toString(), "name" to name)
    }
 
    private fun stopPreview() {
        previewHandler.removeCallbacksAndMessages(null)
        preview?.stop()
        preview = null
    }

    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (alarmMode) return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(false)
                setTurnScreenOn(false)
            } else {
                moveTaskToBack(true)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "time_pilot/lockscreen")
            .setMethodCallHandler { call, result ->
                if (call.method == "leave") {
                    leaveAlarmMode()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "time_pilot/alarm_sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickAndImport" -> {
                        if (pendingPick != null) {
                            result.error("BUSY", "Pemilih file sedang terbuka.", null)
                        } else {
                            pendingPick = result
                            pickAudio.launch(arrayOf("audio/*"))
                        }
                    }
                    "preview" -> {
                        stopPreview()
                        val uri = Uri.parse(call.argument<String>("uri"))
                        val r = RingtoneManager.getRingtone(this, uri)
                        if (r == null) {
                            result.error("PREVIEW_FAILED", "Suara tidak bisa diputar.", null)
                        } else {
                            r.audioAttributes = AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build()
                            r.play()
                            preview = r
                            previewHandler.postDelayed({ stopPreview() }, 5000)
                            result.success(null)
                        }
                    }
                    "stopPreview" -> {
                        stopPreview()
                        result.success(null)
                    }
                    "remove" -> {
                        try {
                            contentResolver.delete(Uri.parse(call.argument<String>("uri")), null, null)
                        } catch (_: Exception) {
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        alarmMode = isLocked()
        allowOverLockScreen()
        registerReceiver(screenOffReceiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        alarmMode = isLocked()
        allowOverLockScreen()
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenOffReceiver)
        } catch (_: Exception) {
        }
        stopPreview()
        super.onDestroy()
    }

    private fun allowOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
    }

    private fun isLocked(): Boolean {
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return km.isKeyguardLocked
    }

    private fun leaveAlarmMode() {
        alarmMode = false
        if (!isLocked()) return
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            km.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                override fun onDismissCancelled() {
                    moveTaskToBack(true)
                }

                override fun onDismissError() {
                    moveTaskToBack(true)
                }
            })
        } else {
            moveTaskToBack(true)
        }
    }
}