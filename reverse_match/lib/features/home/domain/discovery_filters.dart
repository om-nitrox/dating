/// Discovery filters the girl applies to her feed. Persisted into the backend
/// `user.preferences` so they survive restarts AND automatically constrain the
/// Ideal Match (both the feed and the ML reveal read the same preferences).
///
/// Age always has a value (it has a backend default). Height and intent are
/// nullable: null means "no filter on this field".
class DiscoveryFilters {
  final int ageMin;
  final int ageMax;
  final int? heightMin; // cm, null = no height filter
  final int? heightMax; // cm
  final String? intent; // dating-intention key, null = Any

  const DiscoveryFilters({
    this.ageMin = ageFloor,
    this.ageMax = 50,
    this.heightMin,
    this.heightMax,
    this.intent,
  });

  // UI bounds.
  static const int ageFloor = 18;
  static const int ageCeil = 60;
  static const int heightFloor = 140; // cm
  static const int heightCeil = 210; // cm

  bool get hasHeight => heightMin != null || heightMax != null;
  bool get hasIntent => intent != null && intent!.isNotEmpty;
  bool get hasAge => ageMin > ageFloor || ageMax < 50;
  bool get isAnyAge => ageMin <= ageFloor && ageMax >= ageCeil;

  /// Whether any filter is narrowing the feed (used to badge the bar).
  bool get isActive => hasHeight || hasIntent || hasAge;

  factory DiscoveryFilters.fromPreferences(Map<String, dynamic> p) {
    int? asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : null);
    String? asStr(dynamic v) =>
        (v is String && v.isNotEmpty) ? v : null;
    return DiscoveryFilters(
      ageMin: asInt(p['ageMin']) ?? ageFloor,
      ageMax: asInt(p['ageMax']) ?? 50,
      heightMin: asInt(p['heightMin']),
      heightMax: asInt(p['heightMax']),
      intent: asStr(p['intent']),
    );
  }

  /// Serialize for the `preferences` PUT. `null`/'' clear the backend filter.
  Map<String, dynamic> toPreferences() => {
        'ageMin': ageMin,
        'ageMax': ageMax,
        'heightMin': heightMin,
        'heightMax': heightMax,
        'intent': intent ?? '',
      };

  /// Format a cm height as e.g. `170 cm · 5'7"`.
  static String formatCm(int cm) {
    final totalInches = (cm / 2.54).round();
    final ft = totalInches ~/ 12;
    final inches = totalInches % 12;
    return "$cm cm · $ft'$inches\"";
  }
}
