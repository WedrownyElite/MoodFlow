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
        val completionPercentage = prefs.getInt("completion_percentage", 0)
        val canLogCurrent = prefs.getBoolean("can_log_current", true)
        val selectedMood = prefs.getInt("selected_mood_$currentSegment", -1)
        
        // Update segment title and indicators
        views.setTextViewText(R.id.segment_title, "${segmentNames[currentSegment]} Mood")
        views.setProgressBar(R.id.completion_progress, 100, completionPercentage, false)
        
        // Update swipe indicators
        views.setViewVisibility(R.id.swipe_indicator_left, if (currentSegment > 0) android.view.View.VISIBLE else android.view.View.GONE)
        views.setViewVisibility(R.id.swipe_indicator_right, if (currentSegment < 2) android.view.View.VISIBLE else android.view.View.GONE)
        views.setViewVisibility(R.id.swipe_left_btn, if (currentSegment > 0) android.view.View.VISIBLE else android.view.View.GONE)
        views.setViewVisibility(R.id.swipe_right_btn, if (currentSegment < 2) android.view.View.VISIBLE else android.view.View.GONE)
        
        val statusText = if (canLogCurrent) "Tap a mood to log quickly" else "Current time slot not available"
        views.setTextViewText(R.id.status_text, statusText)
        
        // Set up mood buttons with selection state - FIXED: Use broadcast instead of activity
        val moodButtonIds = arrayOf(R.id.mood_1, R.id.mood_2, R.id.mood_3, R.id.mood_4, R.id.mood_5)
        val moodActions = arrayOf("mood_1", "mood_2", "mood_3", "mood_4", "mood_5")
        
        for (i in moodButtonIds.indices) {
            val isSelected = selectedMood == (i + 1)
            
            // Set selection state
            if (isSelected) {
                views.setInt(moodButtonIds[i], "setBackgroundResource", R.drawable.mood_button_selected_bg)
                views.setFloat(moodButtonIds[i], "setAlpha", 1.0f)
            } else {
                views.setInt(moodButtonIds[i], "setBackgroundResource", R.drawable.mood_button_bg)
                views.setFloat(moodButtonIds[i], "setAlpha", if (canLogCurrent) 1.0f else 0.5f)
            }
            
            if (canLogCurrent) {
                // FIXED: Send broadcast to widget provider instead of opening activity
                val intent = Intent(context, MoodFlowWidgetProvider::class.java).apply {
                    action = "MOOD_SELECTED"
                    putExtra("mood_index", i + 1)
                    putExtra("segment", currentSegment)
                    putExtra("appWidgetId", appWidgetId)
                }
                
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    1000 + (currentSegment * 10) + i,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                views.setOnClickPendingIntent(moodButtonIds[i], pendingIntent)
            }
        }
        
        // Set up navigation buttons - FIXED: Use broadcast
        if (currentSegment > 0) {
            val leftIntent = Intent(context, MoodFlowWidgetProvider::class.java).apply {
                action = "SWIPE_LEFT"
                putExtra("appWidgetId", appWidgetId)
            }
            val leftPendingIntent = PendingIntent.getBroadcast(
                context, 3000, leftIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.swipe_left_btn, leftPendingIntent)
        }
        
        if (currentSegment < 2) {
            val rightIntent = Intent(context, MoodFlowWidgetProvider::class.java).apply {
                action = "SWIPE_RIGHT"
                putExtra("appWidgetId", appWidgetId)
            }
            val rightPendingIntent = PendingIntent.getBroadcast(
                context, 3001, rightIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.swipe_right_btn, rightPendingIntent)
        }
        
        // Set up "Open App" button - ONLY this should open the activity
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("widget_action", "open_mood_log")
            putExtra("segment", currentSegment)
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            context, 2000, openAppIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.open_mood_log_btn, openAppPendingIntent)
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            "MOOD_SELECTED" -> {
                val moodIndex = intent.getIntExtra("mood_index", 0)
                val segment = intent.getIntExtra("segment", 0)
                val appWidgetId = intent.getIntExtra("appWidgetId", 0)
                
                // Handle mood selection without opening app
                handleMoodSelection(context, moodIndex, segment, appWidgetId)
            }
            "SWIPE_LEFT" -> {
                val appWidgetId = intent.getIntExtra("appWidgetId", 0)
                handleSwipeLeft(context, appWidgetId)
            }
            "SWIPE_RIGHT" -> {
                val appWidgetId = intent.getIntExtra("appWidgetId", 0)
                handleSwipeRight(context, appWidgetId)
            }
        }
    }
    
    private fun handleMoodSelection(context: Context, moodIndex: Int, segment: Int, appWidgetId: Int) {
        // Convert mood index to rating
        val rating = when (moodIndex) {
            1 -> 2.0
            2 -> 4.0
            3 -> 6.0
            4 -> 8.0
            5 -> 10.0
            else -> 6.0
        }
        
        // Save to SharedPreferences so Flutter can pick it up
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putInt("selected_mood_$segment", moodIndex)
            putFloat("widget_mood_rating_$segment", rating.toFloat())
            putInt("widget_mood_segment", segment)
            putLong("widget_mood_timestamp", System.currentTimeMillis())
            apply()
        }
        
        // Notify Flutter about the mood selection via method channel
        val flutterIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("widget_action", "mood_selected_background")
            putExtra("mood_index", moodIndex)
            putExtra("segment", segment)
            putExtra("rating", rating)
        }
        
        try {
            context.startActivity(flutterIntent)
        } catch (e: Exception) {
            // If app is not running, the mood will be saved when it starts
        }
        
        // Update widget display
        val appWidgetManager = AppWidgetManager.getInstance(context)
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }
    
    private fun handleSwipeLeft(context: Context, appWidgetId: Int) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val currentSegment = prefs.getInt("current_segment_index", 0)
        
        if (currentSegment > 0) {
            prefs.edit().putInt("current_segment_index", currentSegment - 1).apply()
            val appWidgetManager = AppWidgetManager.getInstance(context)
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
    
    private fun handleSwipeRight(context: Context, appWidgetId: Int) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val currentSegment = prefs.getInt("current_segment_index", 0)
        
        if (currentSegment < 2) {
            prefs.edit().putInt("current_segment_index", currentSegment + 1).apply()
            val appWidgetManager = AppWidgetManager.getInstance(context)
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
}