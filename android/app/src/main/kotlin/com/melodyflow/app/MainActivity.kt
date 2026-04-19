package com.melodyflow.app

import android.content.Intent
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity extends AudioServiceActivity so just_audio/audio_service
 * can find and bind the media session when the app comes up.
 *
 * Also handles incoming widget_action intents from MelodyWidgetProvider.
 * These come in as Intent extras; we pass them to Flutter via a
 * MethodChannel so the Dart audio handler can react.
 */
class MainActivity : AudioServiceActivity() {

    private val CHANNEL = "com.melodyflow.app/widget"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWidgetIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Handled post-resume
    }

    override fun onPostResume() {
        super.onPostResume()
        if (intent.getBooleanExtra("widget_silent", false)) {
            window.decorView.postDelayed({
                if (!isFinishing) finish()
            }, 200)
        }
    }

    private fun handleWidgetIntent(intent: Intent?) {
        val action = intent?.getStringExtra("widget_action") ?: return
        intent.removeExtra("widget_action")
        methodChannel?.invokeMethod("widgetAction", action)
    }
}
