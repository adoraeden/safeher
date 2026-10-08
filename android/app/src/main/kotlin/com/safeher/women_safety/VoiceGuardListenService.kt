package com.safeher.women_safety


import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.util.concurrent.Executors
import java.util.zip.ZipInputStream

/** Carries events from the service to Flutter (only works while Flutter is running). */
object VoiceGuardBridge {
    @Volatile
    var sink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun emit(type: String, value: String) {
        mainHandler.post {
            sink?.success(mapOf("type" to type, "value" to value))
        }
    }
}

/**
 * Foreground service that keeps the microphone open and listens for the
 * user's emergency phrases using Vosk (offline, continuous, no restart cycles).
 */
class VoiceGuardListenService : Service() {

    companion object {
        const val ACTION_START = "com.safeher.women_safety.VOICE_GUARD_START"
        const val ACTION_STOP = "com.safeher.women_safety.VOICE_GUARD_STOP"
        const val ACTION_PAUSE = "com.safeher.women_safety.VOICE_GUARD_PAUSE"
        const val ACTION_RESUME = "com.safeher.women_safety.VOICE_GUARD_RESUME"
        const val EXTRA_PHRASES = "phrases"

        private const val TAG = "VoiceGuardNative"
        private const val CHANNEL_LISTENING = "voice_guard_listening"
        private const val CHANNEL_ALERT = "voice_guard_alert_v2"
        private const val NOTIF_LISTENING = 7101
        private const val NOTIF_ALERT = 7102
        private const val SAMPLE_RATE = 16000
        private const val MODEL_ASSET =
            "flutter_assets/assets/models/vosk-model-small-en-us-0.15.zip"

        // Microphone boost for distance. Speech quieter than TARGET_RMS is
        // amplified (up to MAX_GAIN times). Silence below NOISE_FLOOR is left alone.
        private const val TARGET_RMS = 2500.0
        private const val NOISE_FLOOR = 120.0
        private const val MAX_GAIN = 8.0

        @Volatile
        var isRunning = false

        // Loading the model takes a few seconds, so keep it for reuse.
        private var cachedModel: Model? = null
    }

    private var recognizer: Recognizer? = null
    private var captureThread: Thread? = null

    @Volatile
    private var capturing = false

    private var phrases: List<String> = emptyList()
    private var lastTriggerAt = 0L
    private var wakeLock: PowerManager.WakeLock? = null

    // One background thread, so start/stop/pause never run at the same time.
    private val worker = Executors.newSingleThreadExecutor()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                phrases = (intent.getStringArrayListExtra(EXTRA_PHRASES) ?: arrayListOf())
                    .map { it.trim().lowercase() }
                    .filter { it.isNotEmpty() }
                if (phrases.isEmpty() || !goForeground()) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                isRunning = true
                acquireWakeLock()
                worker.execute { beginListening() }
            }
            ACTION_PAUSE -> worker.execute {
                stopListening()
                VoiceGuardBridge.emit("status", "paused")
            }
            ACTION_RESUME -> worker.execute { beginListening() }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    // Called when the user swipes SafeHer away from recent apps.
    override fun onTaskRemoved(rootIntent: Intent?) {
        showAlert(
            "Voice Guard is OFF",
            "SafeHer was closed, so Voice Guard stopped. Open SafeHer and turn it on again.",
            fullScreen = true,
            target = warningIntent()
        )
        VoiceGuardBridge.emit("status", "stopped")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        isRunning = false
        worker.execute { stopListening() }
        worker.shutdown()
        releaseWakeLock()
        super.onDestroy()
    }

    // ── Listening ────────────────────────────────────────────────────────────

    private fun beginListening() {
        try {
            stopListening()
            VoiceGuardBridge.emit("status", "loading")
            val model = loadModel()
            // No restricted word list: normal speech is recognized as normal words.
            val rec = Recognizer(model, SAMPLE_RATE.toFloat())
            rec.setMaxAlternatives(3)
            recognizer = rec
            if (startCapture(rec)) {
                VoiceGuardBridge.emit("status", "listening")
            } else {
                rec.close()
                recognizer = null
                VoiceGuardBridge.emit("error", "Microphone is busy or unavailable")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Could not start listening", e)
            VoiceGuardBridge.emit("error", e.message ?: "Could not start listening")
        }
    }

    private fun stopListening() {
        capturing = false
        try {
            captureThread?.join(1500)
        } catch (e: Exception) {
            Log.w(TAG, "Error waiting for capture thread", e)
        }
        captureThread = null
        try {
            recognizer?.close()
        } catch (e: Exception) {
            Log.w(TAG, "Error closing recognizer", e)
        }
        recognizer = null
    }

    private fun startCapture(rec: Recognizer): Boolean {
        val minBuf = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuf <= 0) return false

        val record = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBuf * 2, 16000)
            )
        } catch (e: Exception) {
            Log.e(TAG, "AudioRecord failed", e)
            return false
        }
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            return false
        }

        val agc = try {
            if (AutomaticGainControl.isAvailable())
                AutomaticGainControl.create(record.audioSessionId)?.apply { enabled = true }
            else null
        } catch (e: Exception) {
            null
        }
        val ns = try {
            if (NoiseSuppressor.isAvailable())
                NoiseSuppressor.create(record.audioSessionId)?.apply { enabled = true }
            else null
        } catch (e: Exception) {
            null
        }

        capturing = true
        val thread = Thread({
            val buffer = ShortArray(4000) // 250 ms of audio
            var gain = 1.0
            try {
                record.startRecording()
                if (record.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                    VoiceGuardBridge.emit("error", "Microphone is busy or unavailable")
                    return@Thread
                }
                while (capturing) {
                    val n = record.read(buffer, 0, buffer.size)
                    if (n < 0) {
                        if (capturing) VoiceGuardBridge.emit("error", "Microphone stopped")
                        break
                    }
                    if (n == 0) continue

                    var sum = 0.0
                    for (i in 0 until n) sum += buffer[i].toDouble() * buffer[i]
                    val rms = Math.sqrt(sum / n)
                    val wanted =
                        if (rms > NOISE_FLOOR) (TARGET_RMS / rms).coerceIn(1.0, MAX_GAIN) else 1.0
                    gain = gain * 0.8 + wanted * 0.2
                    for (i in 0 until n) {
                        buffer[i] = (buffer[i] * gain).toInt().coerceIn(-32768, 32767).toShort()
                    }

                    val sentenceDone = rec.acceptWaveForm(buffer, n)
                    handleHypothesis(
                        if (sentenceDone) rec.result else rec.partialResult,
                        sentenceDone
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Capture loop error", e)
                if (capturing) VoiceGuardBridge.emit("error", e.message ?: "Microphone error")
            } finally {
                try {
                    record.stop()
                } catch (e: Exception) {
                }
                record.release()
                agc?.release()
                ns?.release()
            }
        }, "VoiceGuardCapture")
        captureThread = thread
        thread.start()
        return true
    }

    private fun handleHypothesis(json: String?, isFinal: Boolean) {
        if (json.isNullOrBlank()) return
        val obj = try {
            JSONObject(json)
        } catch (e: Exception) {
            return
        }

        // Final results carry the top guesses; partial results carry one.
        val texts = mutableListOf<String>()
        if (isFinal) {
            val alts = obj.optJSONArray("alternatives")
            if (alts != null) {
                for (i in 0 until alts.length()) texts.add(alts.getJSONObject(i).optString("text", ""))
            } else {
                texts.add(obj.optString("text", ""))
            }
        } else {
            texts.add(obj.optString("partial", ""))
        }

        texts.firstOrNull { it.isNotBlank() }?.let { VoiceGuardBridge.emit("heard", it) }

        for (text in texts) {
            val words = text.lowercase()
                .replace("[unk]", " ")
                .replace(Regex("[^a-z' ]"), " ")
                .split(" ")
                .filter { it.isNotEmpty() }
            if (words.isEmpty()) continue

            for (phrase in phrases) {
                val phraseWords = phrase.split(" ").filter { it.isNotEmpty() }
                if (phraseWords.isEmpty()) continue
                // Single words must wait for the finished sentence; they are too
                // easy to confuse with half-heard sounds.
                if (!isFinal && phraseWords.size == 1) continue
                if (matchesPhrase(words, phraseWords)) {
                    triggerDetected(words.joinToString(" "))
                    return
                }
            }
        }
    }

    private fun matchesPhrase(words: List<String>, phraseWords: List<String>): Boolean {
        if (phraseWords.size == 1) {
            return words.any { it == phraseWords[0] } // single word: exact only
        }
        if (words.size < phraseWords.size) return false
        for (start in 0..(words.size - phraseWords.size)) {
            var all = true
            for (j in phraseWords.indices) {
                if (!wordClose(words[start + j], phraseWords[j])) {
                    all = false
                    break
                }
            }
            if (all) return true
        }
        return false
    }

    // Same word, or one letter different for words of 4+ letters.
    private fun wordClose(a: String, b: String): Boolean {
        if (a == b) return true
        if (a.length < 4 || b.length < 4) return false
        return levenshtein(a, b) <= 1
    }

    private fun levenshtein(a: String, b: String): Int {
        val dp = IntArray(b.length + 1) { it }
        for (i in 1..a.length) {
            var prev = dp[0]
            dp[0] = i
            for (j in 1..b.length) {
                val tmp = dp[j]
                dp[j] = minOf(dp[j] + 1, dp[j - 1] + 1, prev + if (a[i - 1] == b[j - 1]) 0 else 1)
                prev = tmp
            }
        }
        return dp[b.length]
    }

    private fun triggerDetected(heard: String) {
        val now = System.currentTimeMillis()
        if (now - lastTriggerAt < 5000) return
        lastTriggerAt = now

        Log.i(TAG, "Phrase heard: $heard")
        if (VoiceGuardBridge.sink != null) {
            VoiceGuardBridge.emit("phrase", heard)
        } else {
            // SafeHer's screen code is not running, so give the user a way in.
            showAlert(
                "Voice Guard heard your emergency phrase",
                "Tap to open SafeHer and start SOS.",
                fullScreen = true
            )
        }
    }

    // Unzips the bundled model once, then loads it.
    private fun loadModel(): Model {
        cachedModel?.let { return it }
        val root = File(filesDir, "vosk-model")
        val ready = File(root, ".ready")
        if (!ready.exists()) {
            root.deleteRecursively()
            root.mkdirs()
            assets.open(MODEL_ASSET).use { raw ->
                ZipInputStream(raw).use { zip ->
                    var entry = zip.nextEntry
                    while (entry != null) {
                        val out = File(root, entry.name)
                        if (!out.canonicalPath.startsWith(root.canonicalPath)) {
                            throw SecurityException("Bad path in model zip")
                        }
                        if (entry.isDirectory) {
                            out.mkdirs()
                        } else {
                            out.parentFile?.mkdirs()
                            out.outputStream().use { zip.copyTo(it) }
                        }
                        zip.closeEntry()
                        entry = zip.nextEntry
                    }
                }
            }
            ready.writeText("ok")
        }
        val modelDir = root.listFiles()?.firstOrNull { it.isDirectory }
            ?: throw IllegalStateException("Voice model folder is missing")
        val model = Model(modelDir.absolutePath)
        cachedModel = model
        return model
    }

    // ── Notifications and power ──────────────────────────────────────────────

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_LISTENING, "Voice Guard listening", NotificationManager.IMPORTANCE_LOW
            )
        )
        val alert = NotificationChannel(
            CHANNEL_ALERT, "Voice Guard alerts", NotificationManager.IMPORTANCE_HIGH
        ).apply {
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 500, 300, 500, 300, 500)
        }
        nm.createNotificationChannel(alert)
    }

    private fun openAppIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    private fun warningIntent(): PendingIntent {
        val intent = Intent(this, VoiceGuardWarningActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            this, 1, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    private fun goForeground(): Boolean {
        createChannels()
        val notification = NotificationCompat.Builder(this, CHANNEL_LISTENING)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("SafeHer Voice Guard is on")
            .setContentText("Listening for your emergency phrase. Don't swipe SafeHer away.")
            .setContentIntent(openAppIntent())
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
        return try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                // Only add location if the user already allowed it. Android 14+
                // crashes the service start otherwise, and Voice Guard must still start.
                val hasLocation = ContextCompat.checkSelfPermission(
                    this, Manifest.permission.ACCESS_FINE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
                if (hasLocation) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                startForeground(NOTIF_LISTENING, notification, type)
            } else {
                startForeground(NOTIF_LISTENING, notification)
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
            VoiceGuardBridge.emit("error", "Could not start background listening: ${e.message}")
            false
        }
    }

    private fun showAlert(
        title: String,
        text: String,
        fullScreen: Boolean,
        target: PendingIntent = openAppIntent()
    ) {
        createChannels()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder = NotificationCompat.Builder(this, CHANNEL_ALERT)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_SOUND)
            .setVibrate(longArrayOf(0, 500, 300, 500, 300, 500))
            .setContentIntent(target)
            .setAutoCancel(true)
        if (fullScreen) {
            builder.setCategory(NotificationCompat.CATEGORY_ALARM)
            builder.setFullScreenIntent(target, true)
        }
        nm.notify(NOTIF_ALERT, builder.build())
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SafeHer:VoiceGuard").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (e: Exception) {
            Log.w(TAG, "Error releasing wake lock", e)
        }
        wakeLock = null
    }
}