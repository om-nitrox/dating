// GENERATED-EQUIVALENT — hand-written from docs/api/openapi.yaml (Phase 0.2).
// Edit the spec, not this file. See packages/api-client-dart/README.md.
//
// All enums use string wire values matching the OpenAPI `enum:` lists exactly.

/// `Gender` — `male | female | nonbinary`.
enum Gender {
  male('male'),
  female('female'),
  nonbinary('nonbinary');

  const Gender(this.wire);
  final String wire;

  static Gender? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in Gender.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}

/// `GenderPreference` — `men | women | everyone`.
enum GenderPreference {
  men('men'),
  women('women'),
  everyone('everyone');

  const GenderPreference(this.wire);
  final String wire;

  static GenderPreference? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in GenderPreference.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}

/// `DatingIntention` — life partner / long term / etc.
enum DatingIntention {
  lifePartner('life_partner'),
  longTerm('long_term'),
  longTermOpenShort('long_term_open_short'),
  shortTermOpenLong('short_term_open_long'),
  shortTerm('short_term'),
  newFriends('new_friends'),
  figuringOut('figuring_out');

  const DatingIntention(this.wire);
  final String wire;

  static DatingIntention? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in DatingIntention.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}

/// `RelationshipType` — `monogamy | non_monogamy | open_to_exploring | prefer_not_to_say`.
enum RelationshipType {
  monogamy('monogamy'),
  nonMonogamy('non_monogamy'),
  openToExploring('open_to_exploring'),
  preferNotToSay('prefer_not_to_say');

  const RelationshipType(this.wire);
  final String wire;

  static RelationshipType? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in RelationshipType.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}

/// `Exercise` — `active | sometimes | never | prefer_not_to_say`.
enum Exercise {
  active('active'),
  sometimes('sometimes'),
  never('never'),
  preferNotToSay('prefer_not_to_say');

  const Exercise(this.wire);
  final String wire;

  static Exercise? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in Exercise.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}

/// `Zodiac` — 12 western zodiac signs.
enum Zodiac {
  aries('aries'),
  taurus('taurus'),
  gemini('gemini'),
  cancer('cancer'),
  leo('leo'),
  virgo('virgo'),
  libra('libra'),
  scorpio('scorpio'),
  sagittarius('sagittarius'),
  capricorn('capricorn'),
  aquarius('aquarius'),
  pisces('pisces');

  const Zodiac(this.wire);
  final String wire;

  static Zodiac? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in Zodiac.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}

/// `Children` — `have | dont_have | prefer_not_to_say`.
enum Children {
  have('have'),
  dontHave('dont_have'),
  preferNotToSay('prefer_not_to_say');

  const Children(this.wire);
  final String wire;

  static Children? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in Children.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}

/// `FamilyPlans` — `want | dont_want | open | not_sure | prefer_not_to_say`.
enum FamilyPlans {
  want('want'),
  dontWant('dont_want'),
  open('open'),
  notSure('not_sure'),
  preferNotToSay('prefer_not_to_say');

  const FamilyPlans(this.wire);
  final String wire;

  static FamilyPlans? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in FamilyPlans.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}

/// `ViceFrequency` — `yes | sometimes | rarely | no | prefer_not_to_say`.
enum ViceFrequency {
  yes('yes'),
  sometimes('sometimes'),
  rarely('rarely'),
  no('no'),
  preferNotToSay('prefer_not_to_say');

  const ViceFrequency(this.wire);
  final String wire;

  static ViceFrequency? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in ViceFrequency.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}

/// `Politics` — `liberal | moderate | conservative | not_political | prefer_not_to_say`.
enum Politics {
  liberal('liberal'),
  moderate('moderate'),
  conservative('conservative'),
  notPolitical('not_political'),
  preferNotToSay('prefer_not_to_say');

  const Politics(this.wire);
  final String wire;

  static Politics? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in Politics.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}

/// `BoostLevel` — `none | bronze | silver | gold`. Differs from `BoostTier`
/// in that it allows `none` (user has no active boost).
enum BoostLevel {
  none('none'),
  bronze('bronze'),
  silver('silver'),
  gold('gold');

  const BoostLevel(this.wire);
  final String wire;

  static BoostLevel? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in BoostLevel.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}

/// `BoostTier` — purchasable tiers: `bronze | silver | gold`.
enum BoostTier {
  bronze('bronze'),
  silver('silver'),
  gold('gold');

  const BoostTier(this.wire);
  final String wire;

  static BoostTier? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in BoostTier.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}

/// `LikeStatus` — `pending | accepted | rejected`.
enum LikeStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected');

  const LikeStatus(this.wire);
  final String wire;

  static LikeStatus? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in LikeStatus.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}

/// `LikeType` — `like | super`.
enum LikeType {
  like('like'),
  superLike('super');

  const LikeType(this.wire);
  final String wire;

  static LikeType? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in LikeType.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}

/// `ReportReason` — `harassment | spam | fake | inappropriate | underage | other`.
enum ReportReason {
  harassment('harassment'),
  spam('spam'),
  fake('fake'),
  inappropriate('inappropriate'),
  underage('underage'),
  other('other');

  const ReportReason(this.wire);
  final String wire;

  static ReportReason? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in ReportReason.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}

/// `SelfieReviewStatus` — `pending_review | approved | rejected`.
enum SelfieReviewStatus {
  pendingReview('pending_review'),
  approved('approved'),
  rejected('rejected');

  const SelfieReviewStatus(this.wire);
  final String wire;

  static SelfieReviewStatus? fromJson(Object? raw) {
    if (raw == null) return null;
    for (final v in SelfieReviewStatus.values) {
      if (v.wire == raw) return v;
    }
    return null;
  }

  String toJson() => wire;
}
