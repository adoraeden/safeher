package com.safeher.women_safety

import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

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
    }

    private fun sendAction(action: String) {
        val intent = Intent(this, VoiceGuardListenService::class.java).apply {
            this.action = action
        }
        startService(intent)
    }
}