import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data/mood_data_service.dart';
import '../screens/mood_history_screen.dart';

class MoodEntryCard extends StatelessWidget {
  final MoodHistoryEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MoodEntryCard({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  String _getMoodEmoji(double rating) {
    final roundedRating = rating.round();
    switch (roundedRating) {
      case 1: return '😭';
      case 2: return '😢';
      case 3: return '😔';
      case 4: return '😕';
      case 5: return '😐';
      case 6: return '🙂';
      case 7: return '😊';
      case 8: return '😄';
      case 9: return '😁';
      case 10: return '🤩';
      default: return '😐';
    }
  }

  Color _getMoodColor(double rating) {
    final intensity = (rating - 1) / 9; // Normalize to 0-1
    
    if (intensity < 0.3) {
      return Colors.red.shade600;
    } else if (intensity < 0.7) {
      return Colors.orange.shade600;
    } else {
      return Colors.green.shade600;
    }
  }

  String _getMoodDescription(double rating) {
    if (rating < 3) return 'Tough day';
    if (rating < 5) return 'Okay day';
    if (rating < 7) return 'Good day';
    if (rating < 9) return 'Great day';
    return 'Amazing day';
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateTime.now().difference(entry.date).inDays == 0;
    final isYesterday = DateTime.now().difference(entry.date).inDays == 1;
    
    String dateText;
    if (isToday) {
      dateText = 'Today';
    } else if (isYesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('EEE, MMM d').format(entry.date);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Date and time segment
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isToday 
                                ? (Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.white 
                                    : Theme.of(context).primaryColor)
                                : Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
                          ),
                        ),
                        Text(
                          MoodDataService.timeSegments[entry.segment],
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Mood rating with emoji
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getMoodColor(entry.rating).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getMoodColor(entry.rating).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getMoodEmoji(entry.rating),
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _getMoodColor(entry.rating),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Action buttons
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Mood description
              const SizedBox(height: 8),
              Text(
                _getMoodDescription(entry.rating),
                style: TextStyle(
                  fontSize: 14,
                  color: _getMoodColor(entry.rating),
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              // Note preview
              if (entry.note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade800
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade600
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Text(
                    entry.note.length > 100 
                        ? '${entry.note.substring(0, 100)}...'
                        : entry.note,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
                    ),
                  ),
                ),
              ],
              
              // Tap hint
              const SizedBox(height: 8),
              Text(
                'Tap to edit',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}