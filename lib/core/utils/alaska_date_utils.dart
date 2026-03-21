/// Alaska Time (AKST) utilities for Polar Glow.
/// Fixes the 1-day shift in EVERY calendar by forcing all booked slots
/// and day keys to true Alaska day boundaries (UTC-9 offset).
/// Works regardless of the user's device timezone (Seattle, Anchorage, etc.).
class AlaskaDateUtils {
  /// Alaska offset from UTC (fixed AKST, not observing DST for day boundaries).
  static const Duration _akstOffset = Duration(hours: 9);

  /// Convert a user-selected calendar day (from TableCalendar) into the
  /// correct UTC Timestamp to store in Firestore.
  /// This ensures the Alaska day boundary is respected.
  static DateTime toAlaskaStorageDate(DateTime selectedLocalDay) {
    final alaskaMidnight = DateTime(
      selectedLocalDay.year,
      selectedLocalDay.month,
      selectedLocalDay.day,
    );
    return alaskaMidnight.toUtc().subtract(_akstOffset);
  }

  /// Convert a Firestore Timestamp back into the correct Alaska calendar day
  /// for TableCalendar markers, lists, and comparisons.
  static DateTime toAlaskaDayKey(DateTime utcDateFromTimestamp) {
    final alaskaDate = utcDateFromTimestamp.add(_akstOffset);
    return DateTime(alaskaDate.year, alaskaDate.month, alaskaDate.day);
  }

  /// String key used for availability documents (yyyy-MM-dd in Alaska time).
  /// This is the most reliable way for daily availability lookups.
  static String toDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
