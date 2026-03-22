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

    // Will hold the shortcut 'type' from static shortcuts.xml or the tile.
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

    override fun onResume() {
        super.onResume()
        // Ensure we always re-read any "type" extra when the activity comes to foreground.
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val type = intent?.getStringExtra("type")
        if (!type.isNullOrEmpty()) {
            // Store until Flutter is ready; will be read via MethodChannel.
            pendingShortcutType = type
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Channel used by Dart to minimize / go home.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "goHome" -> {
                    try {
                        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(homeIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("GO_HOME_ERROR", e.message, null)
                    }
                }

                "sendHomeIntent" -> {
                    try {
                        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(homeIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("HOME_INTENT_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // Channel to send initial shortcut/tile "type" into Flutter.
        val launchChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LAUNCH_CHANNEL
        )

        // Dart calls "getInitialShortcutType" during startup to retrieve it.
        launchChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShortcutType" -> {
                    result.success(pendingShortcutType)
                    // Consume so it isn’t reused accidentally.
                    pendingShortcutType = null
                }
                else -> result.notImplemented()
            }
        }
    }
}
