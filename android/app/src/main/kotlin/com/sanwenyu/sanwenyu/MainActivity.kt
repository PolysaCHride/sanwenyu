package com.sanwenyu.sanwenyu

import android.database.ContentObserver
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * 播放页手势的原生端：
 * - 亮度只改当前窗口亮度，不改系统设置；
 * - 音量直接调 Android 的 STREAM_MUSIC，和系统音量条/硬件键保持一致。
 */
class MainActivity : FlutterActivity() {
    private val brightnessChannel = "sanwenyu/brightness"
    private val volumeChannel = "sanwenyu/volume"
    private val volumeEventsChannel = "sanwenyu/volume_events"

    private var volumeObserver: ContentObserver? = null
    private var volumeSink: EventChannel.EventSink? = null
    private var lastVolume: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureBrightness(flutterEngine)
        configureVolume(flutterEngine)
    }

    private fun configureBrightness(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, brightnessChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "get" -> {
                        val attr = window.attributes.screenBrightness
                        val value = if (attr >= 0f) {
                            attr
                        } else {
                            // 首次进入时窗口亮度是 -1，用系统亮度作为手势起点。
                            val system = Settings.System.getInt(
                                contentResolver,
                                Settings.System.SCREEN_BRIGHTNESS,
                                255,
                            )
                            (system / 255f).coerceIn(0.01f, 1f)
                        }
                        result.success(value.toDouble())
                    }
                    "set" -> {
                        val raw = call.argument<Double>("value") ?: 1.0
                        val value = raw.toFloat().coerceIn(0.01f, 1f)
                        val params = window.attributes
                        params.screenBrightness = value
                        window.attributes = params
                        result.success(null)
                    }
                    "reset" -> {
                        val params = window.attributes
                        params.screenBrightness = -1f
                        window.attributes = params
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun configureVolume(flutterEngine: FlutterEngine) {
        val audio = getSystemService(AUDIO_SERVICE) as AudioManager
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, volumeChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "get" -> result.success(volumeState(audio))
                    "set" -> {
                        try {
                            val ratio = (call.argument<Double>("value") ?: 0.0)
                                .coerceIn(0.0, 1.0)
                            val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                            val index = (ratio * max).toInt().coerceIn(0, max)
                            audio.setStreamVolume(AudioManager.STREAM_MUSIC, index, 0)
                            result.success(volumeState(audio))
                        } catch (e: SecurityException) {
                            result.error("volume_permission", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, volumeEventsChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volumeSink = events
                    lastVolume = null
                    emitVolume(audio)
                    val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
                        override fun onChange(selfChange: Boolean) {
                            emitVolume(audio)
                        }
                    }
                    volumeObserver = observer
                    contentResolver.registerContentObserver(
                        Settings.System.CONTENT_URI,
                        true,
                        observer,
                    )
                }

                override fun onCancel(arguments: Any?) {
                    volumeObserver?.let { contentResolver.unregisterContentObserver(it) }
                    volumeObserver = null
                    volumeSink = null
                    lastVolume = null
                }
            })
    }

    private fun emitVolume(audio: AudioManager) {
        val sink = volumeSink ?: return
        val state = volumeState(audio)
        val current = state["current"] as Int
        if (current == lastVolume) return
        lastVolume = current
        sink.success(state)
    }

    private fun volumeState(audio: AudioManager): Map<String, Any> {
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val current = audio.getStreamVolume(AudioManager.STREAM_MUSIC)
        val fixed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            audio.isVolumeFixed
        } else {
            false
        }
        return mapOf(
            "current" to current,
            "max" to max,
            "fixed" to fixed,
        )
    }
}
