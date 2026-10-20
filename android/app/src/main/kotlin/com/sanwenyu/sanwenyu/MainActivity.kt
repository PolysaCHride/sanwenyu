package com.sanwenyu.sanwenyu

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 播放页亮度手势的原生端。
 *
 * 只改当前窗口亮度，不改系统设置；退出播放页后由系统恢复正常。
 */
class MainActivity : FlutterActivity() {
    private val channelName = "sanwenyu/brightness"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "get" -> {
                        val value = window.attributes.screenBrightness
                        result.success(if (value < 0f) null else value.toDouble())
                    }
                    "set" -> {
                        val raw = call.argument<Double>("value") ?: 1.0
                        val value = raw.toFloat().coerceIn(0.01f, 1f)
                        val params = window.attributes
                        params.screenBrightness = value
                        window.attributes = params
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
