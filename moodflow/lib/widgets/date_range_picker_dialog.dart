// Fixed version of date_range_picker_dialog.dart with proper dark mode support
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDateRangePickerDialog extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const CustomDateRangePickerDialog({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<CustomDateRangePickerDialog> createState() => _CustomDateRangePickerDialogState();
}

class _CustomDateRangePickerDialogState extends State<CustomDateRangePickerDialog> {
  DateTime? _startDate;
  DateTime? _endDate;

  final List<Map<String, dynamic>> _quickRanges = [
    {'label': 'Last 7 days', 'days': 7},
    {'label': 'Last 30 days', 'days': 30},
    {'label': 'Last 3 months', 'days': 90},
    {'label': 'Last 6 months', 'days': 180},
    {'label': 'Last year', 'days': 365},
    {'label': 'This month', 'type': 'thisMonth'},
    {'label': 'Last month', 'type': 'lastMonth'},
    {'label': 'This year', 'type': 'thisYear'},
  ];

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  void _setQuickRange(Map<String, dynamic> range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (range['type']) {
      case 'thisMonth':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = today;
        break;
      case 'lastMonth':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        _startDate = lastMonth;
        _endDate = DateTime(now.year, now.month, 0); // Last day of previous month
        break;
      case 'thisYear':
        _startDate = DateTime(now.year, 1, 1);
        _endDate = today;
        break;
      default:
        if (range['days'] != null) {
          _endDate = today;
          _startDate = today.subtract(Duration(days: range['days'] as int));
        }
    }

    setState(() {});
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: _endDate ?? DateTime.now(),
      helpText: 'Select start date',
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // If end date is before start date, adjust it
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select end date',
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        // If start date is after end date, adjust it
        if (_startDate != null && _startDate!.isAfter(picked)) {
          _startDate = picked;
        }
      });
    }
  }

  bool _isValidRange() {
    return _startDate != null && _endDate != null;
  }

  int _getDayCount() {
    if (!_isValidRange()) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Define theme-aware colors
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDarkMode ? Colors.white : Colors.black);
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600);
    final borderColor = isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400;

    return Dialog(
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Date Range',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Quick range buttons
            Text(
              'Quick Ranges',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              flex: 3,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _quickRanges.length,
                itemBuilder: (context, index) {
                  final range = _quickRanges[index];
                  return OutlinedButton(
                    onPressed: () => _setQuickRange(range),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                    ),
                    child: Text(
                      range['label'],
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Custom date selection
            Text(
              'Custom Range',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectStartDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                        color: isDarkMode ? Colors.grey.shade800.withOpacity(0.3) : Colors.transparent,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _startDate != null
                                ? DateFormat('MMM d, y').format(_startDate!)
                                : 'Select date',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _startDate != null ? textColor : subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: InkWell(
                    onTap: _selectEndDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                        color: isDarkMode ? Colors.grey.shade800.withOpacity(0.3) : Colors.transparent,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End Date',
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _endDate != null
                                ? DateFormat('MMM d, y').format(_endDate!)
                                : 'Select date',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _endDate != null ? textColor : subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Range info - FIXED FOR DARK MODE
            if (_isValidRange()) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: isDarkMode ? Theme.of(context).primaryColor.withOpacity(0.9) : Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Selected range: ${_getDayCount()} days',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Theme.of(context).primaryColor.withOpacity(0.9) : Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: textColor),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isValidRange()
                        ? () {
                      Navigator.of(context).pop(<String, DateTime>{
                        'startDate': _startDate!,
                        'endDate': _endDate!,
                      });
                    }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}