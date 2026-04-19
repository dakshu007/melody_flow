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
        // On first startup, the intent that launched us might contain a
        // widget_action extra. Handle it once Flutter is ready.
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Subsequent widget taps while app is already running land here
        setIntent(intent)
        handleWidgetIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // If launched silently from a control-button tap, don't bring the
        // window forward. Let the service handle the action, then finish.
        if (intent.getBooleanExtra("widget_silent", false)) {
            // Must wait until after Flutter is up — finish in onPostResume
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        if (intent.getBooleanExtra("widget_silent", false)) {
            // Give Flutter one frame to process the method call, then finish
            window.decorView.postDelayed({
                if (!isFinishing) finish()
            }, 200)
        }
    }

    private fun handleWidgetIntent(intent: Intent?) {
        val action = intent?.getStringExtra("widget_action") ?: return
        // Clear the extra so we don't handle it twice
        intent.removeExtra("widget_action")
        // Send to Flutter
        methodChannel?.invokeMethod("widgetAction", action)
    }
}
