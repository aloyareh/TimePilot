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

/**
 * Manifest memberi showWhenLocked/turnScreenOn supaya alarm bisa menyalakan layar
 * dan tampil di atas layar kunci. Agar app tidak "menempel" di atas layar kunci
 * pada pemakaian biasa:
 *  - alarmMode = true bila aktivitas dibuka saat HP terkunci (alarm).
 *  - Saat layar mati di luar alarmMode, task dipindah ke belakang, sehingga layar
 *    kunci muncul normal saat HP dibangunkan.
 *  - Setelah tantangan alarm selesai, Dart memanggil "leave": minta buka kunci;
 *    bila dibatalkan, task disembunyikan di belakang layar kunci.
 */
class MainActivity : FlutterFragmentActivity() {
    private var alarmMode = false

    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (!alarmMode) moveTaskToBack(true)
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
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        alarmMode = isLocked()
        registerReceiver(screenOffReceiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        alarmMode = isLocked()
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenOffReceiver)
        } catch (_: Exception) {
        }
        super.onDestroy()
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