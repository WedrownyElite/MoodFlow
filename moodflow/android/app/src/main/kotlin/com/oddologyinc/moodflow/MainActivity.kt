package com.oddologyinc.moodflow

import android.app.backup.BackupManager
import android.content.Intent
import android.content.Context
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
        
        // Enhanced widget interaction channel
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
              "checkPendingMoods" -> {
                  val pendingMoods = checkForPendingWidgetMoods()
                  result.success(pendingMoods)
              }
              "clearPendingMoods" -> {
                  clearPendingWidgetMoods()
                  result.success(true)
              }
              // ADD THIS NEW CASE - this is what was missing
              "forceNavigateToMoodLog" -> {
                  val segment = call.argument<Int>("segment") ?: 0
                  val fromWidget = call.argument<Boolean>("fromWidget") ?: false
                  
                  // Force navigate to mood log (this is handled on Flutter side)
                  result.success(mapOf(
                      "segment" to segment,
                      "fromWidget" to fromWidget,
                      "forceNavigation" to true
                  ))
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
    
    override fun onResume() {
        super.onResume()
        
        // Check for pending widget moods when app becomes active
        processPendingWidgetMoods()
    }
    
    private fun handleIntent(intent: Intent?) {
        intent?.let {
            val widgetAction = it.getStringExtra("widget_action")
            val fromWidget = it.getBooleanExtra("from_widget", false)
            val forceMoodLog = it.getBooleanExtra("force_mood_log", false)
            
            if (widgetAction != null && fromWidget) {
                // Delay to ensure Flutter is ready
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    handleWidgetAction(widgetAction, forceMoodLog)
                }, 300)
            }
        }
    }
    
    private fun handleWidgetAction(action: String, forceMoodLog: Boolean = false) {
        try {
            // Send the action to Flutter via MethodChannel
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                val channel = MethodChannel(messenger, WIDGET_CHANNEL)
                
                when (action) {
                    "open_mood_log" -> {
                        val segment = intent.getIntExtra("segment", 0)
                        
                        // FIXED: Always navigate to mood log when force_mood_log is true
                        if (forceMoodLog) {
                            channel.invokeMethod("forceNavigateToMoodLog", mapOf(
                                "segment" to segment,
                                "fromWidget" to true
                            ))
                        } else {
                            channel.invokeMethod("openMoodLog", mapOf(
                                "segment" to segment,
                                "fromWidget" to true
                            ))
                        }
                    }
                    else -> {
                        channel.invokeMethod("widgetActionReceived", mapOf("action" to action))
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    // Check for pending widget mood selections
    private fun checkForPendingWidgetMoods(): List<Map<String, Any>> {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val pendingMoods = mutableListOf<Map<String, Any>>()
        
        if (prefs.getBoolean("widget_mood_pending", false)) {
            val segment = prefs.getInt("widget_mood_segment", 0)
            val rating = prefs.getFloat("widget_mood_rating_$segment", 6.0f)
            val timestamp = prefs.getLong("widget_mood_timestamp", 0)
            
            pendingMoods.add(mapOf(
                "segment" to segment,
                "rating" to rating.toDouble(),
                "timestamp" to timestamp,
                "source" to "widget"
            ))
        }
        
        return pendingMoods
    }
    
    // Process pending widget moods when app becomes active
    private fun processPendingWidgetMoods() {
        val pendingMoods = checkForPendingWidgetMoods()
        
        if (pendingMoods.isNotEmpty()) {
            // Send to Flutter for processing
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                val channel = MethodChannel(messenger, WIDGET_CHANNEL)
                
                for (mood in pendingMoods) {
                    channel.invokeMethod("processPendingWidgetMood", mood)
                }
            }
            
            // Clear pending flag
            clearPendingWidgetMoods()
        }
    }
    
    // Clear pending widget moods flag
    private fun clearPendingWidgetMoods() {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("widget_mood_pending", false).apply()
    }
}