package com.example.ecoreward_bin

import android.media.AudioAttributes
import android.media.SoundPool
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    // Short UI sounds (scan / success / badge) via Android's built-in SoundPool, so the app
    // needs no audio package. Sounds are copied from the Flutter assets once, then cached.
    private var pool: SoundPool? = null
    private val ids = mutableMapOf<String, Int>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ecoreward/sounds").setMethodCallHandler { call, result ->
            when (call.method) {
                "load" -> {
                    (call.arguments as? List<*>)?.filterIsInstance<String>()?.forEach { load(it) }
                    result.success(null)
                }
                "play" -> {
                    val id = ids[call.argument<String>("asset")]
                    val volume = (call.argument<Double>("volume") ?: 0.6).toFloat()
                    if (id != null) pool?.play(id, volume, volume, 1, 0, 1f)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun load(asset: String) {
        if (ids.containsKey(asset)) return
        try {
            val p = pool ?: SoundPool.Builder()
                .setMaxStreams(2)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .build().also { pool = it }
            val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
            val out = File(cacheDir, "sound_" + asset.substringAfterLast('/'))
            assets.open(key).use { input -> out.outputStream().use { input.copyTo(it) } }
            ids[asset] = p.load(out.path, 1)
        } catch (_: Exception) {
            // Sound is optional; a missing or unreadable file just stays silent.
        }
    }

    override fun onDestroy() {
        pool?.release()
        pool = null
        super.onDestroy()
    }
}
