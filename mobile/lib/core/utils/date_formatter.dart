import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _displayFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _monthFormat = DateFormat('MMM yyyy');

  static String formatDate(dynamic date) {
    if (date == null) return '-';
    DateTime? dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is String) {
      dt = DateTime.tryParse(date);
    }
    if (dt == null) return date.toString();
    return _displayFormat.format(dt.toLocal());
  }

  static String formatDateTime(dynamic date) {
    if (date == null) return '-';
    DateTime? dt;
    if (date is DateTime) {
      dt = date;
    } else if (date is String) {
      dt = DateTime.tryParse(date);
    }
    if (dt == null) return date.toString();
    return _dateTimeFormat.format(dt.toLocal());
  }

  static String formatMonth(String? yyyyMm) {
    if (yyyyMm == null || yyyyMm.isEmpty) return '-';
    try {
      final parts = yyyyMm.split('-');
      if (parts.length == 2) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        return _monthFormat.format(DateTime(year, month));
      }
    } catch (_) {}
    return yyyyMm;
  }
}
