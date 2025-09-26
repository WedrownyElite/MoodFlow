package com.oddologyinc.moodflow

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class MoodFlowWidgetProvider : AppWidgetProvider() {
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
    
    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.mood_widget)
        
        // Get data from shared preferences (set by Flutter)
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        // Use Flutter's key format for home_widget package
        val currentSegment = prefs.getInt("flutter.current_segment_index", 0)
        val segmentNames = arrayOf("Morning", "Midday", "Evening")
        val segmentQuestions = arrayOf(
            "How's your morning going?",
            "How's your midday going?", 
            "How's your evening going?"
        )
        val canLogCurrent = prefs.getBoolean("flutter.can_log_current", true)
        val selectedMood = prefs.getInt("flutter.selected_mood_$currentSegment", -1)
        
        val hasPrevSegment = currentSegment > 0
        val hasNextSegment = currentSegment < 2 && canLogSegment(currentSegment + 1, prefs)
        
        // Previous segment button
        if (hasPrevSegment) {
            val prevIntent = Intent(context, MoodFlowWidgetProvider::class.java).apply {
                action = "SWITCH_SEGMENT"
                putExtra("target_segment", currentSegment - 1)
                putExtra("appWidgetId", appWidgetId)
            }
            val prevPendingIntent = PendingIntent.getBroadcast(
                context,
                7000 + appWidgetId,
                prevIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.prev_segment_btn, prevPendingIntent)
            views.setFloat(R.id.prev_segment_btn, "setAlpha", 1.0f)
        } else {
            views.setOnClickPendingIntent(R.id.prev_segment_btn, null)
            views.setFloat(R.id.prev_segment_btn, "setAlpha", 0.3f)
        }
        
        // Next segment button
        if (hasNextSegment) {
            val nextIntent = Intent(context, MoodFlowWidgetProvider::class.java).apply {
                action = "SWITCH_SEGMENT"
                putExtra("target_segment", currentSegment + 1)
                putExtra("appWidgetId", appWidgetId)
            }
            val nextPendingIntent = PendingIntent.getBroadcast(
                context,
                8000 + appWidgetId,
                nextIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.next_segment_btn, nextPendingIntent)
            views.setFloat(R.id.next_segment_btn, "setAlpha", 1.0f)
        } else {
            views.setOnClickPendingIntent(R.id.next_segment_btn, null)
            views.setFloat(R.id.next_segment_btn, "setAlpha", 0.3f)
        }
        
        // Update header and segment info
        views.setTextViewText(R.id.current_segment_display, segmentNames[currentSegment])
        views.setTextViewText(R.id.segment_title, segmentQuestions[currentSegment])
        
        // Update status text
        val statusText = if (canLogCurrent) {
            "Tap an emoji to log your mood"
        } else {
            "This time slot isn't available yet"
        }
        views.setTextViewText(R.id.status_text, statusText)
        
        // Set up 5 emoji mood buttons
        val moodButtonIds = arrayOf(R.id.mood_1, R.id.mood_2, R.id.mood_3, R.id.mood_4, R.id.mood_5)
        
        for (i in moodButtonIds.indices) {
            val moodIndex = i + 1
            val isSelected = selectedMood == moodIndex
            
            // FIXED: Properly set selection state and background
            if (isSelected) {
                views.setInt(moodButtonIds[i], "setBackgroundResource", R.drawable.mood_button_selected_bg)
                views.setFloat(moodButtonIds[i], "setAlpha", 1.0f)
                views.setBoolean(moodButtonIds[i], "setSelected", true) // NEW: Set selected state
            } else {
                views.setInt(moodButtonIds[i], "setBackgroundResource", R.drawable.mood_button_bg)
                views.setFloat(moodButtonIds[i], "setAlpha", if (canLogCurrent) 1.0f else 0.5f)
                views.setBoolean(moodButtonIds[i], "setSelected", false) // NEW: Clear selected state
            }
            
            if (canLogCurrent) {
                // FIXED: Use unique action names and pass all necessary data
                val moodIntent = Intent(context, MoodFlowWidgetProvider::class.java).apply {
                    action = "MOOD_SELECTED_${moodIndex}_SEGMENT_${currentSegment}" // More specific action
                    putExtra("mood_index", moodIndex)
                    putExtra("segment", currentSegment)
                    putExtra("appWidgetId", appWidgetId)
                }
                
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    (currentSegment * 1000) + (moodIndex * 100) + appWidgetId, // More unique request code
                    moodIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                views.setOnClickPendingIntent(moodButtonIds[i], pendingIntent)
            } else {
                views.setOnClickPendingIntent(moodButtonIds[i], null)
            }
        }
        
        // Set up "Open App" button - ONLY this opens the app
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("widget_action", "open_mood_log")
            putExtra("segment", currentSegment)
            putExtra("from_widget", true)
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            context, 
            5000 + appWidgetId, // Unique request code
            openAppIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.open_app_btn, openAppPendingIntent)
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when {
            intent.action?.startsWith("MOOD_SELECTED") == true -> {
                val moodIndex = intent.getIntExtra("mood_index", 0)
                val segment = intent.getIntExtra("segment", 0)
                val appWidgetId = intent.getIntExtra("appWidgetId", 0)
                
                // Handle mood selection WITHOUT opening app
                handleMoodSelectionBackground(context, moodIndex, segment, appWidgetId)
            }
            intent.action == "SWITCH_SEGMENT" -> {
                val targetSegment = intent.getIntExtra("target_segment", 0)
                val appWidgetId = intent.getIntExtra("appWidgetId", 0)
                
                // Update the current segment preference
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.edit().putInt("flutter.current_segment_index", targetSegment).apply()
                
                // Update the widget immediately
                val appWidgetManager = AppWidgetManager.getInstance(context)
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
            intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                // Handle widget updates normally
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
                if (appWidgetIds != null) {
                    onUpdate(context, appWidgetManager, appWidgetIds)
                }
            }
        }
    }

    private fun handleMoodSelectionBackground(context: Context, moodIndex: Int, segment: Int, appWidgetId: Int) {
        // Convert mood index to rating (1-5 -> 2.0, 4.0, 6.0, 8.0, 10.0)
        val rating = when (moodIndex) {
            1 -> 2.0  // 😢 Very Bad
            2 -> 4.0  // 🙁 Bad  
            3 -> 6.0  // 😐 Neutral
            4 -> 8.0  // 🙂 Good
            5 -> 10.0 // 😊 Very Good
            else -> 6.0
        }
        
        // FIXED: Save to CORRECT SharedPreferences with Flutter's key format
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault()).format(java.util.Date())
        
        // Use Flutter's exact key format from MoodDataService
        val moodKey = "flutter.mood_${today}_${segment}"
        
        // Create mood data in Flutter's exact format
        val moodData = org.json.JSONObject().apply {
            put("rating", rating)
            put("note", "Quick mood from widget")
            put("timestamp", java.time.Instant.now().toString())
            put("moodDate", java.time.LocalDate.now().toString() + "T00:00:00.000")
            put("lastModified", java.time.Instant.now().toString())
        }
        
        prefs.edit().apply {
            // Save the mood data in Flutter's format
            putString(moodKey, moodData.toString())
            
            // Update widget state
            putInt("flutter.selected_mood_$segment", moodIndex)
            putFloat("flutter.widget_mood_rating_$segment", rating.toFloat())
            putInt("flutter.widget_mood_segment", segment)
            putLong("flutter.widget_mood_timestamp", System.currentTimeMillis())
            putBoolean("flutter.widget_mood_pending", true)
            apply()
        }
        
        // Immediately update the widget to show selection
        val appWidgetManager = AppWidgetManager.getInstance(context)
        updateAppWidget(context, appWidgetManager, appWidgetId)
        
        // Send broadcast to Flutter app if it's running
        val flutterBroadcast = Intent().apply {
            action = "com.oddologyinc.moodflow.WIDGET_MOOD_SELECTED"
            putExtra("mood_index", moodIndex)
            putExtra("segment", segment)
            putExtra("rating", rating)
            putExtra("background_save", true)
        }
        
        try {
            context.sendBroadcast(flutterBroadcast)
        } catch (e: Exception) {
            // Silent fail - app might not be running
        }
    }
    
    // Helper method to check if a segment can be logged
    private fun canLogSegment(segment: Int, prefs: SharedPreferences): Boolean {
        return when (segment) {
            0 -> true // Morning always available
            1 -> {
                val middayHour = prefs.getInt("flutter.midday_hour", 12)
                val currentHour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
                currentHour >= middayHour
            }
            2 -> {
                val eveningHour = prefs.getInt("flutter.evening_hour", 18)
                val currentHour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
                currentHour >= eveningHour
            }
            else -> false
        }
    }
}