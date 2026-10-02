/// Shared `yyyy-MM-dd` formatting for local calendar dates, used by
/// [DailyUsage]'s JSON `date` field and by data/app_paths.dart's per-day
/// usage filenames so both stay in lockstep.
String formatDateStamp(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Parses a `yyyy-MM-dd` stamp back into a local midnight [DateTime].
DateTime parseDateStamp(String stamp) {
  final parts = stamp.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// Truncates a [DateTime] to local midnight, so two moments on the same
/// calendar day compare equal.
DateTime dateOnly(DateTime dateTime) => DateTime(dateTime.year, dateTime.month, dateTime.day);
