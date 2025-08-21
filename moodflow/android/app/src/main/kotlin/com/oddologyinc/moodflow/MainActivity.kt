package com.oddologyinc.moodflow

import android.app.backup.BackupManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "auto_backup"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
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
    }
}