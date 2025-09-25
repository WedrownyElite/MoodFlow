package com.oddologyinc.moodflow

import android.app.backup.BackupManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "auto_backup"
    private val WIDGET_CHANNEL = "widget_interaction"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Existing backup channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAutoBackupAvailable" -> {
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                }
                "requestBackup" -> {
                    try {
                        val backupManager = BackupManager(this)
                        backupManager.dataChanged()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("BACKUP_FAILED", e.message, null)
                    }
                }
                "getBackupStatus" -> {
                    result.success(mapOf(
                        "available" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M),
                        "enabled" to true,
                        "type" to "Android Auto Backup"
                    ))
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // NEW: Widget interaction channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "handleWidgetAction" -> {
                    val action = call.argument<String>("action")
                    if (action != null) {
                        handleWidgetAction(action)
                        result.success(true)
                    } else {
                        result.error("INVALID_ACTION", "Action cannot be null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle widget interactions from intent
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?) {
        intent?.let {
            val widgetAction = it.getStringExtra("widget_action")
            if (widgetAction != null) {
                // Delay to ensure Flutter is ready
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    handleWidgetAction(widgetAction)
                }, 500)
            }
        }
    }
    
    private fun handleWidgetAction(action: String) {
        try {
            // Send the action to Flutter via MethodChannel
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                val channel = MethodChannel(messenger, WIDGET_CHANNEL)
                
                // Check if this is a background mood save
                if (action == "mood_selected_background") {
                    // Get the mood data from SharedPreferences
                    val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                    val segment = prefs.getInt("widget_mood_segment", 0)
                    val rating = prefs.getFloat("widget_mood_rating_$segment", 6.0f)
                    val timestamp = prefs.getLong("widget_mood_timestamp", 0)
                    
                    channel.invokeMethod("widgetMoodSelected", mapOf(
                        "segment" to segment,
                        "rating" to rating.toDouble(),
                        "timestamp" to timestamp
                    ))
                } else {
                    channel.invokeMethod("widgetActionReceived", mapOf("action" to action))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}