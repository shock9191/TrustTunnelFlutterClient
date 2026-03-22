package com.adguard.trusttunnel

import android.content.Intent
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val APP_CHANNEL = "app_channel"
    private val LAUNCH_CHANNEL = "launch_channel"

    // Will hold the shortcut 'type' from static shortcuts.xml
    private var pendingShortcutType: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val type = intent?.getStringExtra("type")
        if (!type.isNullOrEmpty()) {
            // Store until Flutter is ready; will be pushed over MethodChannel
            pendingShortcutType = type
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Channel used by Dart to minimize app
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "goHome" -> {
                    try {
                        val intent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("GO_HOME_ERROR", e.message, null)
                    }
                }

                "sendHomeIntent" -> {
                    try {
                        val intent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("HOME_INTENT_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // Channel to send initial shortcut type into Flutter
        val launchChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LAUNCH_CHANNEL
        )

        // When Dart side is ready, it will call "getInitialShortcutType"
        launchChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShortcutType" -> {
                    result.success(pendingShortcutType)
                    // Consume it so it is not reused accidentally
                    pendingShortcutType = null
                }
                else -> result.notImplemented()
            }
        }
    }
}
