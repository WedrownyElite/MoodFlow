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
        
        // Set up mood buttons with selection state
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
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("widget_action", "${moodActions[i]}_segment_$currentSegment")
                    putExtra("segment", currentSegment)
                }
                
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    1000 + (currentSegment * 10) + i,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                views.setOnClickPendingIntent(moodButtonIds[i], pendingIntent)
            }
        }
        
        // Set up navigation buttons
        if (currentSegment > 0) {
            val leftIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("widget_action", "swipe_left")
            }
            val leftPendingIntent = PendingIntent.getActivity(
                context, 3000, leftIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.swipe_left_btn, leftPendingIntent)
        }
        
        if (currentSegment < 2) {
            val rightIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("widget_action", "swipe_right")
            }
            val rightPendingIntent = PendingIntent.getActivity(
                context, 3001, rightIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.swipe_right_btn, rightPendingIntent)
        }
        
        // Set up "Open App" button
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
}