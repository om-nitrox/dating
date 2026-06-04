/// Single source of truth for closed-enum taxonomies the backend validates
/// against. The backend stores lowercase snake_case keys (see
/// `backend/src/domain/taxonomies.js`); the UI shows human-readable labels.
///
/// Pattern: store the KEY in onboarding state and on the API call, look up
/// the label via the `.label` map at display time.
library;

/// Politics — closed enum on the backend.
class Politics {
  static const Map<String, String> labels = {
    'liberal': 'Liberal',
    'moderate': 'Moderate',
    'conservative': 'Conservative',
    'not_political': 'Not political',
    'prefer_not_to_say': 'Prefer not to say',
  };
  static List<String> get keys => labels.keys.toList();
  static List<String> get displayLabels => labels.values.toList();
  static String? keyOf(String? label) =>
      label == null ? null : labels.entries
          .firstWhere((e) => e.value == label,
              orElse: () => const MapEntry('', ''))
          .key
          .let((k) => k.isEmpty ? null : k);
}

/// Dating intentions — closed enum.
class DatingIntentions {
  static const Map<String, String> labels = {
    'life_partner': 'Life partner',
    'long_term': 'Long-term relationship',
    'long_term_open_short': 'Long-term relationship, open to short',
    'short_term_open_long': 'Short-term relationship, open to long',
    'short_term': 'Short-term relationship',
    'new_friends': 'New friends',
    'figuring_out': 'Figuring out my dating goals',
  };
  static List<String> get keys => labels.keys.toList();
  static List<String> get displayLabels => labels.values.toList();
}

/// Relationship type — closed enum.
class RelationshipType {
  static const Map<String, String> labels = {
    'monogamy': 'Monogamy',
    'non_monogamy': 'Non-monogamy',
    'open_to_exploring': 'Figuring out my relationship type',
    'prefer_not_to_say': 'Prefer not to say',
  };
  static List<String> get keys => labels.keys.toList();
  static List<String> get displayLabels => labels.values.toList();
}

/// Children — closed enum.
class Children {
  static const Map<String, String> labels = {
    'dont_have': "Don't have children",
    'have': 'Have children',
    'prefer_not_to_say': 'Prefer not to say',
  };
  static List<String> get keys => labels.keys.toList();
  static List<String> get displayLabels => labels.values.toList();
}

/// Family plans — closed enum.
class FamilyPlans {
  static const Map<String, String> labels = {
    'want': 'Want children',
    'dont_want': "Don't want children",
    'open': 'Open to children',
    'not_sure': 'Not sure yet',
    'prefer_not_to_say': 'Prefer not to say',
  };
  static List<String> get keys => labels.keys.toList();
  static List<String> get displayLabels => labels.values.toList();
}

/// Vice levels — used by drinking / smoking / marijuana / drugs.
class ViceLevels {
  static const Map<String, String> labels = {
    'yes': 'Yes',
    'sometimes': 'Sometimes',
    'rarely': 'Rarely',
    'no': 'No',
    'prefer_not_to_say': 'Prefer not to say',
  };
  static List<String> get keys => labels.keys.toList();
  static List<String> get displayLabels => labels.values.toList();
}

/// Exercise — closed enum on the backend.
class Exercise {
  static const Map<String, String> labels = {
    'active': 'Active',
    'sometimes': 'Sometimes',
    'never': 'Never',
    'prefer_not_to_say': 'Prefer not to say',
  };
  static List<String> get keys => labels.keys.toList();
  static List<String> get displayLabels => labels.values.toList();
}

/// Zodiac sign — closed enum on the backend (12 signs).
class Zodiac {
  static const Map<String, String> labels = {
    'aries': 'Aries',
    'taurus': 'Taurus',
    'gemini': 'Gemini',
    'cancer': 'Cancer',
    'leo': 'Leo',
    'virgo': 'Virgo',
    'libra': 'Libra',
    'scorpio': 'Scorpio',
    'sagittarius': 'Sagittarius',
    'capricorn': 'Capricorn',
    'aquarius': 'Aquarius',
    'pisces': 'Pisces',
  };
  static List<String> get keys => labels.keys.toList();
  static List<String> get displayLabels => labels.values.toList();
}

/// Interests — the backend stores free-form strings, but the ideal-match ML
/// encoder multi-hots against this exact top-30 list, so the values sent MUST
/// match these casings to count toward compatibility.
class Interests {
  static const List<String> options = [
    'Travel', 'Cooking', 'Reading', 'Music', 'Movies', 'Fitness', 'Yoga',
    'Hiking', 'Photography', 'Art', 'Dancing', 'Gaming', 'Coffee', 'Wine',
    'Food', 'Fashion', 'Sports', 'Pets', 'Beach', 'Coding', 'Writing',
    'Theatre', 'Concerts', 'Running', 'Cycling', 'Swimming', 'Volunteering',
    'Meditation', 'Podcasts', 'Astrology',
  ];
}

/// Gender preference — what gender(s) the user wants to date.
class GenderPreference {
  static const Map<String, String> labels = {
    'men': 'Men',
    'women': 'Women',
    'everyone': 'Everyone',
  };
  static List<String> get keys => labels.keys.toList();
  static List<String> get displayLabels => labels.values.toList();
}

extension _NullableLet<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
