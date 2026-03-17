import 'package:intl/intl.dart';

class AppFormatters {
  static final DateFormat _monthDay = DateFormat('MMM d');
  static final DateFormat _weekdayMonthDay = DateFormat('EEE, MMM d');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _time = DateFormat('h:mm a');

  static String monthDay(DateTime date) => _monthDay.format(date);

  static String weekdayMonthDay(DateTime date) => _weekdayMonthDay.format(date);

  static String monthYear(DateTime date) => _monthYear.format(date);

  static String time(DateTime date) => _time.format(date);

  static String duration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours == 0) {
      return '${duration.inMinutes}m';
    }

    if (minutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${minutes}m';
  }

  static String decimal(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }
}
