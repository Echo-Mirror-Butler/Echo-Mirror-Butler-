import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/themes/app_theme.dart';
import '../../data/models/log_entry_model.dart';

/// Calendar widget that shows dates with log entries marked
class LoggingCalendar extends StatefulWidget {
  final List<LogEntryModel> entries;
  final Function(DateTime) onDateSelected;

  const LoggingCalendar({
    super.key,
    required this.entries,
    required this.onDateSelected,
  });

  @override
  State<LoggingCalendar> createState() => _LoggingCalendarState();
}

class _LoggingCalendarState extends State<LoggingCalendar> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  /// Get set of dates that have log entries
  /// Normalizes dates to local time to avoid timezone issues
  Set<DateTime> get _markedDates {
    return widget.entries
        .map((entry) {
          // Convert UTC to local and normalize to date only
          final localDate = entry.date.isUtc ? entry.date.toLocal() : entry.date;
          return DateTime(localDate.year, localDate.month, localDate.day);
        })
        .toSet();
  }

  /// Check if a date has a log entry
  bool _hasEntry(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return _markedDates.contains(normalizedDate);
  }

  /// Get the log entry for a specific date
  LogEntryModel? _getEntryForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    try {
      return widget.entries.firstWhere(
        (entry) {
          // Normalize entry date to local time for comparison
          final localDate = entry.date.isUtc ? entry.date.toLocal() : entry.date;
          final entryDate = DateTime(localDate.year, localDate.month, localDate.day);
          return entryDate.isAtSameMomentAs(normalizedDate);
        },
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Date',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Calendar
            TableCalendar<LogEntryModel?>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: (day) {
                if (_hasEntry(day)) {
                  try {
                    return [_getEntryForDate(day)];
                  } catch (e) {
                    return [];
                  }
                }
                return [];
              },
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  shape: BoxShape.circle,
                ),
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(
                  color: AppTheme.accentColor,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: AppTheme.primaryColor,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: AppTheme.primaryColor,
                ),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });

                  // If the selected date has an entry, notify parent
                  if (_hasEntry(selectedDay)) {
                    widget.onDateSelected(selectedDay);
                    Navigator.of(context).pop();
                  }
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isNotEmpty) {
                    return Positioned(
                      bottom: 1,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(theme, 'Today', AppTheme.primaryColor.withOpacity(0.5)),
                const SizedBox(width: 16),
                _buildLegendItem(theme, 'Has Entry', AppTheme.accentColor),
                const SizedBox(width: 16),
                _buildLegendItem(theme, 'Selected', AppTheme.primaryColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(ThemeData theme, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

