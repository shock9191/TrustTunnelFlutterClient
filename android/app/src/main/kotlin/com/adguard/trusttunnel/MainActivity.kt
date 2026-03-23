package com.adguard.trusttunnel

import android.content.Intent
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val TOGGLE_CHANNEL = "toggle_channel"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val toggleChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TOGGLE_CHANNEL
        )

        // If we were launched from the Quick Settings tile, immediately notify Dart
        if (intent?.action == "com.adguard.trusttunnel.TOGGLE_VPN") {
            toggleChannel.invokeMethod("toggleFromPlatform", null)
        }
    }
}
