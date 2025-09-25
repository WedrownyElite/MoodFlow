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
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        
        val currentSegment = prefs.getInt("current_segment_index", 0)
        val segmentNames = arrayOf("Morning", "Midday", "Evening")
        val segmentQuestions = arrayOf(
            "How's your morning going?",
            "How's your midday going?", 
            "How's your evening going?"
        )
        val canLogCurrent = prefs.getBoolean("can_log_current", true)
        val selectedMood = prefs.getInt("selected_mood_$currentSegment", -1)
        
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
            
            // Set selection state and alpha
            if (isSelected) {
                views.setInt(moodButtonIds[i], "setBackgroundResource", R.drawable.mood_button_selected_bg)
                views.setFloat(moodButtonIds[i], "setAlpha", 1.0f)
                views.setBoolean(moodButtonIds[i], "setSelected", true)
            } else {
                views.setInt(moodButtonIds[i], "setBackgroundResource", R.drawable.mood_button_bg)
                views.setFloat(moodButtonIds[i], "setAlpha", if (canLogCurrent) 1.0f else 0.5f)
                views.setBoolean(moodButtonIds[i], "setSelected", false)
            }
            
            if (canLogCurrent) {
                // Create broadcast intent for mood selection (NO app opening)
                val moodIntent = Intent(context, MoodFlowWidgetProvider::class.java).apply {
                    action = "MOOD_SELECTED"
                    putExtra("mood_index", moodIndex)
                    putExtra("segment", currentSegment)
                    putExtra("appWidgetId", appWidgetId)
                }
                
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    2000 + (currentSegment * 10) + i, // Unique request code
                    moodIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                views.setOnClickPendingIntent(moodButtonIds[i], pendingIntent)
            } else {
                // Disable clicks for unavailable segments
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
        
        when (intent.action) {
            "MOOD_SELECTED" -> {
                val moodIndex = intent.getIntExtra("mood_index", 0)
                val segment = intent.getIntExtra("segment", 0)
                val appWidgetId = intent.getIntExtra("appWidgetId", 0)
                
                // Handle mood selection WITHOUT opening app
                handleMoodSelectionBackground(context, moodIndex, segment, appWidgetId)
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
        
        // Save mood selection and update widget display
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putInt("selected_mood_$segment", moodIndex)
            putFloat("widget_mood_rating_$segment", rating.toFloat())
            putInt("widget_mood_segment", segment)
            putLong("widget_mood_timestamp", System.currentTimeMillis())
            putBoolean("widget_mood_pending", true) // Flag for Flutter to pick up
            apply()
        }
        
        // Show brief feedback by updating widget immediately
        val appWidgetManager = AppWidgetManager.getInstance(context)
        updateAppWidget(context, appWidgetManager, appWidgetId)
        
        // Optionally: Send a broadcast to Flutter app if it's running
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
}