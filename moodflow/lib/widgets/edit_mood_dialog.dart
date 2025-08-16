import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/data/mood_data_service.dart';

class EditMoodDialog extends StatefulWidget {
  final double initialRating;
  final String initialNote;
  final DateTime date;
  final int segment;

  const EditMoodDialog({
    super.key,
    required this.initialRating,
    required this.initialNote,
    required this.date,
    required this.segment,
  });

  @override
  State<EditMoodDialog> createState() => _EditMoodDialogState();
}

class _EditMoodDialogState extends State<EditMoodDialog> {
  late double _rating;
  late TextEditingController _noteController;
  late FocusNode _noteFocusNode;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _noteController = TextEditingController(text: widget.initialNote);
    _noteFocusNode = FocusNode();
    
    _noteFocusNode.addListener(() {
      setState(() {
        _isTyping = _noteFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final isToday = DateTime.now().difference(widget.date).inDays == 0;
    final isYesterday = DateTime.now().difference(widget.date).inDays == 1;
    
    String dateText;
    if (isToday) {
      dateText = 'Today';
    } else if (isYesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('EEE, MMM d').format(widget.date);
    }

    return Dialog(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Mood',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$dateText • ${MoodDataService.timeSegments[widget.segment]}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Current mood display with scaling animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: _isTyping ? 60 : 100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(fontSize: _isTyping ? 24 : 48),
                        child: Text(_getMoodEmoji(_rating)),
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: _isTyping ? 16 : 24,
                          fontWeight: FontWeight.bold,
                          color: _getMoodColor(_rating),
                        ),
                        child: Text(_rating.toStringAsFixed(1)),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Mood slider
              const Text(
                'How were you feeling?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('😢', style: TextStyle(fontSize: 20)),
                  Text('😐', style: TextStyle(fontSize: 20)),
                  Text('😊', style: TextStyle(fontSize: 20)),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  valueIndicatorTextStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                  showValueIndicator: ShowValueIndicator.onlyForDiscrete,
                  valueIndicatorColor: Colors.black87,
                ),
                child: Slider(
                  value: _rating,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${_getMoodEmoji(_rating)} ${_rating.round()}',
                  onChanged: (value) {
                    setState(() {
                      _rating = value;
                    });
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Note editor
              const Text(
                'Notes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: BoxConstraints(
                  minHeight: _isTyping ? 100 : 120,
                  maxHeight: _isTyping ? 140 : 200,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _noteController,
                  focusNode: _noteFocusNode,
                  maxLines: null,
                  minLines: _isTyping ? 3 : 5,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'How was your day? What happened?',
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop({
                          'rating': _rating,
                          'note': _noteController.text,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getMoodColor(_rating),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}