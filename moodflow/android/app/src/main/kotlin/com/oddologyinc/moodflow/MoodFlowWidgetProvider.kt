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
        
        val currentSegment = prefs.getString("current_segment", "Morning") ?: "Morning"
        val completionPercentage = prefs.getInt("completion_percentage", 0)
        val canLogCurrent = prefs.getBoolean("can_log_current", true)
        
        // Update widget content
        views.setTextViewText(R.id.current_segment, currentSegment)
        views.setProgressBar(R.id.completion_progress, 100, completionPercentage, false)
        
        val statusText = if (canLogCurrent) "Tap a mood to log quickly" else "Current time slot not available"
        views.setTextViewText(R.id.status_text, statusText)
        
        // Set up click listeners for mood buttons with specific mood values
        val moodButtonIds = arrayOf(R.id.mood_1, R.id.mood_2, R.id.mood_3, R.id.mood_4, R.id.mood_5)
        val moodActions = arrayOf("mood_1", "mood_2", "mood_3", "mood_4", "mood_5")
        
        for (i in moodButtonIds.indices) {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                // Pass the mood action as data
                putExtra("widget_action", moodActions[i])
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context,
                1000 + i, // Unique request code for each button
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            views.setOnClickPendingIntent(moodButtonIds[i], pendingIntent)
        }
        
        // Set up click listener for the widget title (general app opening)
        val titleIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("widget_action", "open_app")
        }
            
        val titlePendingIntent = PendingIntent.getActivity(
            context,
            2000,
            titleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        views.setOnClickPendingIntent(R.id.widget_title, titlePendingIntent)
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}