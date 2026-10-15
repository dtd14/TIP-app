abstract final class DateFormatter {
  static String date(DateTime value) {
    final day = value.toLocal();
    return '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
  }

  static String range(DateTime start, DateTime end) =>
      '${date(start)} – ${date(end)}';
}
