package vn.giadinh.nhac_uong_thuoc

import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.AudioAttributes
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Giọng đọc tiếng Việt dùng bộ đọc có sẵn của Android.
 * Âm thanh đi theo âm lượng BÁO THỨC (giống tiếng chuông), nên vẫn nghe được
 * khi máy để im lặng hoặc âm lượng nhạc nhỏ.
 */
class MainActivity : FlutterActivity() {
    private var tts: TextToSpeech? = null
    private var ttsState = 0 // 0 = chưa khởi tạo, 1 = đang khởi tạo, 2 = sẵn sàng, 3 = lỗi
    private val pending = mutableListOf<(TextToSpeech?) -> Unit>()
    private val vietnamese: Locale = Locale.forLanguageTag("vi-VN")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nhac_uong_thuoc/giong_noi")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text") ?: ""
                        val rate = (call.argument<Double>("rate") ?: 0.85).toFloat()
                        withTts { t ->
                            if (t == null) {
                                result.success(false)
                            } else {
                                t.setSpeechRate(rate)
                                val r = t.speak(text, TextToSpeech.QUEUE_FLUSH, null, "nhac_uong_thuoc")
                                result.success(r == TextToSpeech.SUCCESS)
                            }
                        }
                    }
                    "stop" -> {
                        tts?.stop()
                        result.success(true)
                    }
                    "vietnameseStatus" -> {
                        // >= 0: có giọng tiếng Việt; -1: thiếu dữ liệu; -2: không hỗ trợ; -3: không có bộ đọc
                        withTts { t ->
                            result.success(t?.isLanguageAvailable(vietnamese) ?: -3)
                        }
                    }
                    "openTtsSettings" -> {
                        result.success(openTtsSettings())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun withTts(action: (TextToSpeech?) -> Unit) {
        when (ttsState) {
            2 -> action(tts)
            1 -> pending.add(action)
            else -> {
                // 0 = chưa khởi tạo; 3 = lần trước lỗi (có thể người dùng vừa cài
                // bộ đọc giọng nói) → khởi tạo lại.
                pending.add(action)
                ttsState = 1
                tts?.shutdown()
                tts = null
                tts = TextToSpeech(applicationContext) { status ->
                    runOnUiThread {
                        val t = tts
                        if (status == TextToSpeech.SUCCESS && t != null) {
                            t.setLanguage(vietnamese)
                            t.setAudioAttributes(
                                AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_ALARM)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                    .build()
                            )
                            ttsState = 2
                        } else {
                            ttsState = 3
                        }
                        val ready = if (ttsState == 2) tts else null
                        val actions = pending.toList()
                        pending.clear()
                        actions.forEach { it(ready) }
                    }
                }
            }
        }
    }

    private fun openTtsSettings(): Boolean {
        val intents = listOf(
            Intent("com.android.settings.TTS_SETTINGS"),
            Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA),
        )
        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (e: ActivityNotFoundException) {
            }
        }
        return false
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        ttsState = 0
        super.onDestroy()
    }
}
