// Private JSON serialization helpers shared by model classes.
// Keeping them in one place avoids re-implementing null-handling per model.

/// Parses an ISO-8601 string into a [DateTime]. Returns null on null/invalid.
DateTime? parseIsoDate(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

/// Serializes a [DateTime] back to an ISO-8601 UTC string, matching the
/// OpenAPI `IsoDateTime` shape (e.g. `2026-05-02T14:30:00.000Z`).
String? encodeIsoDate(DateTime? value) =>
    value?.toUtc().toIso8601String();

/// Coerces a JSON list of strings into `List<String>`. Returns an empty list
/// for null/non-list inputs so we can apply spec-level `default: []`.
List<String> coerceStringList(Object? raw) {
  if (raw is List) {
    return raw.map((e) => e?.toString() ?? '').toList(growable: false);
  }
  return const <String>[];
}

/// Maps a JSON list to typed models via [fromJson]. Returns `[]` on null.
List<T> coerceList<T>(
  Object? raw,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((m) => fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }
  return <T>[];
}

/// Coerces any numeric JSON value to `double`. Returns null on null.
double? coerceDouble(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}

/// Coerces any numeric JSON value to `int`. Returns null on null.
int? coerceInt(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}
