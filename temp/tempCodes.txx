
// for report screen
DateTimeRange _getRange() {
    if (_viewMode == 0) {
      return DateTimeRange(start: _selectedDate, end: _selectedDate);
    } else if (_viewMode == 1) {
      final startOfWeek = _selectedDate.subtract(
        Duration(days: (_selectedDate.weekday + 1) % 7),
      );
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return DateTimeRange(start: startOfWeek, end: endOfWeek);
    } else {
      final jSelected = Jalali.fromDateTime(_selectedDate);
      final jStart = jSelected.copy(day: 1);
      final jEnd = jSelected.copy(day: jSelected.monthLength);
      return DateTimeRange(start: jStart.toDateTime(), end: jEnd.toDateTime());
    }
}