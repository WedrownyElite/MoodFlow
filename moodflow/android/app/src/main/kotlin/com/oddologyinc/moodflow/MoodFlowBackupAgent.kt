package com.oddologyinc.moodflow

import android.app.backup.BackupAgentHelper
import android.app.backup.SharedPreferencesBackupHelper

class MoodFlowBackupAgent : BackupAgentHelper() {
    
    // A key to uniquely identify the set of backup data
    private val PREFS_BACKUP_KEY = "prefs"
    
    override fun onCreate() {
        // Allocate a helper and add it to the backup agent
        val helper = SharedPreferencesBackupHelper(this, getDefaultSharedPreferencesName(this))
        addHelper(PREFS_BACKUP_KEY, helper)
    }
    
    private fun getDefaultSharedPreferencesName(context: android.content.Context): String {
        return context.packageName + "_preferences"
    }
}