// debug_data_screen.dart - Add this to help debug data persistence issues

import 'package:mood_flow/services/utils/logger.dart';
import 'package:flutter/material.dart';
import '../services/data/mood_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugDataScreen extends StatefulWidget {
  const DebugDataScreen({super.key});

  @override
  State<DebugDataScreen> createState() => _DebugDataScreenState();
}

class _DebugDataScreenState extends State<DebugDataScreen> {
  final List<String> _debugLog = [];
  bool _isLoading = false;

  void _addLog(String message) {
    setState(() {
      _debugLog.add(
          '${DateTime.now().toIso8601String().substring(11, 19)}: $message');
    });
    Logger.dataService(message);
  }

  Future<void> _testSaveAndLoad() async {
    setState(() {
      _isLoading = true;
      _debugLog.clear();
    });

    try {
      final testDate = DateTime.now();
      const testSegment = 0; // Morning
      const testRating = 7.5;
      const testNote = "Test note for debugging";

      _addLog("🧪 Starting save/load test...");
      _addLog("Test data: Rating=$testRating, Note='$testNote'");

      // Test save
      _addLog("💾 Attempting to save...");
      final saveSuccess = await MoodDataService.saveMood(
          testDate, testSegment, testRating, testNote);
      _addLog("💾 Save result: $saveSuccess");

      // Wait a moment
      await Future.delayed(const Duration(milliseconds: 500));

      // Test load
      _addLog("📖 Attempting to load...");
      final loadedData = await MoodDataService.loadMood(testDate, testSegment);
      _addLog("📖 Loaded data: $loadedData");

      if (loadedData != null) {
        final loadedRating = loadedData['rating'];
        final loadedNote = loadedData['note'];

        _addLog(
            "✅ Rating match: $loadedRating == $testRating? ${loadedRating == testRating}");
        _addLog(
            "✅ Note match: '$loadedNote' == '$testNote'? ${loadedNote == testNote}");

        if (loadedRating == testRating && loadedNote == testNote) {
          _addLog("🎉 TEST PASSED: Data persistence is working!");
        } else {
          _addLog("❌ TEST FAILED: Data doesn't match!");
        }
      } else {
        _addLog("❌ TEST FAILED: No data loaded!");
      }
    } catch (e) {
      _addLog("❌ TEST ERROR: $e");
    }

    setState(() => _isLoading = false);
  }

  Future<void> _listAllStoredData() async {
    setState(() => _isLoading = true);

    try {
      _addLog("🔍 Listing all stored mood data...");

      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final moodKeys = allKeys.where((key) => key.startsWith('mood_')).toList();

      _addLog("📊 Found ${moodKeys.length} mood entries:");

      if (moodKeys.isEmpty) {
        _addLog("📭 No mood data found in storage");
      } else {
        for (final key in moodKeys) {
          final value = prefs.getString(key);
          _addLog("  $key: $value");
        }
      }

      // Also check for other relevant keys
      final otherKeys = allKeys
          .where((key) =>
              key.contains('backup') ||
              key.contains('notification') ||
              key.contains('goal'))
          .toList();

      if (otherKeys.isNotEmpty) {
        _addLog("🔧 Other app data keys (${otherKeys.length}):");
        for (final key in otherKeys) {
          _addLog("  $key");
        }
      }
    } catch (e) {
      _addLog("❌ Error listing data: $e");
    }

    setState(() => _isLoading = false);
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('This will delete ALL mood data. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        _addLog("🗑️ Clearing all mood data...");
        await MoodDataService.clearAllMoods();
        _addLog("✅ All mood data cleared");
      } catch (e) {
        _addLog("❌ Error clearing data: $e");
      }

      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Data'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Control buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.bug_report, size: 16),
                  label: const Text('Test Save/Load'),
                  onPressed: _isLoading ? null : _testSaveAndLoad,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.list, size: 16),
                  label: const Text('List All Data'),
                  onPressed: _isLoading ? null : _listAllStoredData,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever, size: 16),
                  label: const Text('Clear All'),
                  onPressed: _isLoading ? null : _clearAllData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),

          // Debug log
          Expanded(
            child: _debugLog.isEmpty
                ? const Center(
                    child: Text(
                      'Run a test to see debug output',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _debugLog.length,
                    itemBuilder: (context, index) {
                      final log = _debugLog[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: log.contains('❌')
                              ? Colors.red.shade50
                              : log.contains('✅') || log.contains('🎉')
                                  ? Colors.green.shade50
                                  : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: log.contains('❌')
                                ? Colors.red.shade200
                                : log.contains('✅') || log.contains('🎉')
                                    ? Colors.green.shade200
                                    : Colors.grey.shade200,
                          ),
                        ),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: log.contains('❌')
                                ? Colors.red.shade800
                                : log.contains('✅') || log.contains('🎉')
                                    ? Colors.green.shade800
                                    : Colors.black87,
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Clear log button
          if (_debugLog.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Log'),
                onPressed: () => setState(() => _debugLog.clear()),
              ),
            ),
        ],
      ),
    );
  }
}
