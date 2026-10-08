package com.safeher.women_safety

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val smsRequestCode = 9001
    private var pendingSmsPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "com.safeher.women_safety/voice_guard")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "start" -> {
                            val phrases = call.argument<List<String>>("phrases") ?: emptyList()
                            val intent = Intent(this, VoiceGuardListenService::class.java).apply {
                                action = VoiceGuardListenService.ACTION_START
                                putStringArrayListExtra(
                                    VoiceGuardListenService.EXTRA_PHRASES, ArrayList(phrases)
                                )
                            }
                            ContextCompat.startForegroundService(this, intent)
                            result.success(true)
                        }
                        "stop" -> {
                            sendAction(VoiceGuardListenService.ACTION_STOP)
                            result.success(true)
                        }
                        "pause" -> {
                            sendAction(VoiceGuardListenService.ACTION_PAUSE)
                            result.success(true)
                        }
                        "resume" -> {
                            sendAction(VoiceGuardListenService.ACTION_RESUME)
                            result.success(true)
                        }
                        "isRunning" -> result.success(VoiceGuardListenService.isRunning)
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("VOICE_GUARD_ERROR", e.message, null)
                }
            }

        EventChannel(messenger, "com.safeher.women_safety/voice_guard_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    VoiceGuardBridge.sink = events
                }

                override fun onCancel(arguments: Any?) {
                    VoiceGuardBridge.sink = null
                }
            })

        MethodChannel(messenger, "com.safeher.women_safety/sms")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(hasSmsPermission())
                    "requestPermission" -> {
                        if (hasSmsPermission()) {
                            result.success(true)
                        } else {
                            pendingSmsPermission?.success(false)
                            pendingSmsPermission = result
                            requestPermissions(arrayOf(Manifest.permission.SEND_SMS), smsRequestCode)
                        }
                    }
                    "send" -> {
                        val phone = call.argument<String>("phone") ?: ""
                        val message = call.argument<String>("message") ?: ""
                        if (phone.isBlank() || message.isBlank() || !hasSmsPermission()) {
                            result.success(false)
                        } else {
                            try {
                                val sms = smsManager()
                                val parts = sms.divideMessage(message)
                                sms.sendMultipartTextMessage(phone, null, parts, null, null)
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == smsRequestCode) {
            pendingSmsPermission?.success(
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            )
            pendingSmsPermission = null
        }
    }

    private fun hasSmsPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) ==
            PackageManager.PERMISSION_GRANTED

    @Suppress("DEPRECATION")
    private fun smsManager(): SmsManager =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java)
        } else {
            SmsManager.getDefault()
        }

    private fun sendAction(action: String) {
        val intent = Intent(this, VoiceGuardListenService::class.java).apply {
            this.action = action
        }
        startService(intent)
    }
}