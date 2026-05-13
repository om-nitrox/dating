// Round-trip tests for the top-level model schemas. Each test builds a
// fixture JSON shaped per the OpenAPI spec examples, decodes it via
// `Model.fromJson`, re-encodes via `toJson`, and verifies structural
// equality between the two payloads.
//
// `structurallyEqual` ignores key order and treats missing/null/default
// values as equivalent so the test doesn't fight model defaults — what we
// actually care about is "did any data get dropped or mutated through the
// round trip?".

import 'dart:convert';

import 'package:reverse_match_api/reverse_match_api.dart';
import 'package:test/test.dart';

void main() {
  group('UserModel round-trip', () {
    test('full payload', () {
      final json = _userFixture();
      final user = UserModel.fromJson(json);
      final round = user.toJson();
      expect(_isStructurallyEqual(json, round), isTrue,
          reason: 'UserModel round-trip lost data:\nIN : ${jsonEncode(json)}\nOUT: ${jsonEncode(round)}');
      expect(user.id, equals('64f5b7c3e4d6f8a1b2c3d4e5'));
      expect(user.gender, Gender.female);
      expect(user.datingIntentions, DatingIntention.longTerm);
      expect(user.boostLevel, BoostLevel.bronze);
    });

    test('minimal payload (only `_id` required)', () {
      final user = UserModel.fromJson({'_id': '64f5b7c3e4d6f8a1b2c3d4e5'});
      final round = user.toJson();
      expect(round['_id'], equals('64f5b7c3e4d6f8a1b2c3d4e5'));
      expect(round['pronouns'], equals(<String>[]));
      expect(round['boostLevel'], equals('none'));
      expect(round['isProfileComplete'], isFalse);
    });

    test('accepts `id` as fallback for `_id`', () {
      final user = UserModel.fromJson({'id': '64f5b7c3e4d6f8a1b2c3d4e5'});
      expect(user.id, equals('64f5b7c3e4d6f8a1b2c3d4e5'));
    });
  });

  test('MatchModel round-trip', () {
    final json = {
      '_id': '64aaaaaaaaaaaaaaaaaaaaaa',
      'users': [
        _userFixture(id: '64aaaaaaaaaaaaaaaaaaaa01'),
        _userFixture(id: '64aaaaaaaaaaaaaaaaaaaa02'),
      ],
      'lastMessage': _messageFixture(),
      'unreadCount': 2,
      'createdAt': '2026-05-02T14:30:00.000Z',
    };
    final match = MatchModel.fromJson(json);
    expect(match.id, equals('64aaaaaaaaaaaaaaaaaaaaaa'));
    expect(match.users, hasLength(2));
    expect(match.lastMessage, isNotNull);
    expect(match.unreadCount, equals(2));
    final round = match.toJson();
    expect(_isStructurallyEqual(json, round), isTrue,
        reason: 'MatchModel round-trip diff:\nIN : ${jsonEncode(json)}\nOUT: ${jsonEncode(round)}');
  });

  test('MessageModel round-trip', () {
    final json = _messageFixture();
    final msg = MessageModel.fromJson(json);
    final round = msg.toJson();
    expect(_isStructurallyEqual(json, round), isTrue);
  });

  test('LikeModel round-trip', () {
    final json = {
      '_id': '64bbbbbbbbbbbbbbbbbbbbbb',
      'fromUser': _userFixture(),
      'status': 'pending',
      'type': 'like',
      'createdAt': '2026-05-02T14:30:00.000Z',
    };
    final like = LikeModel.fromJson(json);
    expect(like.status, LikeStatus.pending);
    expect(like.type, LikeType.like);
    final round = like.toJson();
    expect(_isStructurallyEqual(json, round), isTrue);
  });

  test('BoostPlanModel round-trip', () {
    final json = {
      'id': 'bronze-30',
      'name': 'Bronze',
      'tier': 'bronze',
      'durationMinutes': 30,
      'priceCents': 99,
      'currency': 'USD',
      'price': r'$0.99',
      'duration': '30 min',
      'label': 'Try it out',
    };
    final plan = BoostPlanModel.fromJson(json);
    expect(plan.tier, BoostTier.bronze);
    expect(plan.durationMinutes, 30);
    expect(_isStructurallyEqual(json, plan.toJson()), isTrue);
  });

  test('BoostStatusModel round-trip (active)', () {
    final json = {
      'active': true,
      'tier': 'gold',
      'expiresAt': '2026-05-02T14:30:00.000Z',
    };
    final status = BoostStatusModel.fromJson(json);
    expect(status.active, isTrue);
    expect(status.tier, BoostTier.gold);
    expect(_isStructurallyEqual(json, status.toJson()), isTrue);
  });

  test('BoostStatusModel round-trip (inactive — nulls)', () {
    final json = {
      'active': false,
      'tier': null,
      'expiresAt': null,
    };
    final status = BoostStatusModel.fromJson(json);
    expect(status.active, isFalse);
    expect(status.tier, isNull);
    expect(status.expiresAt, isNull);
    // toJson always emits the keys (with null values) for nullable fields
    final round = status.toJson();
    expect(round['active'], isFalse);
    expect(round['tier'], isNull);
  });

  test('ErrorResponse parses nested error shape', () {
    final json = {
      'error': {
        'code': 'VALIDATION_FAILED',
        'message': 'Email is required',
        'requestId': 'req-abc-123',
      }
    };
    final err = ErrorResponse.fromJson(json);
    expect(err.code, 'VALIDATION_FAILED');
    expect(err.message, 'Email is required');
    expect(err.requestId, 'req-abc-123');
    expect(_isStructurallyEqual(json, err.toJson()), isTrue);
  });

  group('Enums', () {
    test('Gender wire values', () {
      expect(Gender.female.toJson(), 'female');
      expect(Gender.fromJson('male'), Gender.male);
      expect(Gender.fromJson('alien'), isNull);
      expect(Gender.fromJson(null), isNull);
    });

    test('DatingIntention wire values include snake_case', () {
      expect(DatingIntention.lifePartner.toJson(), 'life_partner');
      expect(DatingIntention.fromJson('long_term_open_short'),
          DatingIntention.longTermOpenShort);
    });

    test('LikeType handles reserved word `super`', () {
      expect(LikeType.superLike.toJson(), 'super');
      expect(LikeType.fromJson('super'), LikeType.superLike);
    });
  });
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Map<String, dynamic> _userFixture({String? id}) => {
      '_id': id ?? '64f5b7c3e4d6f8a1b2c3d4e5',
      'email': 'jane@example.com',
      'name': 'Jane',
      'age': 27,
      'dob': '1999-04-15T00:00:00.000Z',
      'gender': 'female',
      'pronouns': ['she/her'],
      'orientation': ['straight'],
      'bio': 'Filter coffee enthusiast.',
      'exercise': 'sometimes',
      'zodiac': 'aries',
      'interests': ['hiking', 'reading'],
      'photos': [
        {
          'url':
              'https://res.cloudinary.com/reverse-match/image/upload/v1/users/u1/a.jpg',
          'publicId': 'users/u1/a',
        }
      ],
      'prompts': [
        {'question': 'My simple pleasures', 'answer': 'Filter coffee'}
      ],
      'height': 168,
      'ethnicity': ['south_asian'],
      'children': 'dont_have',
      'familyPlans': 'want',
      'hometown': 'Mumbai',
      'jobTitle': 'Engineer',
      'workplace': 'Reverse Match',
      'education': 'BTech',
      'religion': 'Hindu',
      'politics': 'liberal',
      'languages': ['English', 'Hindi'],
      'datingIntentions': 'long_term',
      'relationshipType': 'monogamy',
      'vices': {
        'drinking': 'sometimes',
        'smoking': 'no',
        'marijuana': 'no',
        'drugs': 'no',
      },
      'location': {
        'coordinates': [72.8777, 19.076],
        'city': 'Mumbai',
        'state': 'Maharashtra',
      },
      'preferences': {
        'ageMin': 25,
        'ageMax': 35,
        'maxDistance': 50,
        'genderPreference': 'men',
      },
      'daysWithoutMatch': 3,
      'boostLevel': 'bronze',
      'isProfileComplete': true,
      'isVerified': true,
      'createdAt': '2026-04-01T00:00:00.000Z',
    };

Map<String, dynamic> _messageFixture() => {
      '_id': '64cccccccccccccccccccccc',
      'matchId': '64dddddddddddddddddddddd',
      'sender': '64eeeeeeeeeeeeeeeeeeeeee',
      'text': 'hello!',
      'seen': false,
      'createdAt': '2026-05-02T14:30:00.000Z',
    };

// ---------------------------------------------------------------------------
// Equality helper
// ---------------------------------------------------------------------------

/// Structural equality that:
///   - is key-order independent;
///   - treats `null`, missing key, and default-equivalent values as
///     interchangeable (e.g. `pronouns: []` round-tripping to an emitted
///     `pronouns: []` is fine even if the input omitted the key);
///   - normalizes ISO date strings via `DateTime.parse` so trailing-zero
///     differences (`2026-05-02T14:30:00Z` vs `2026-05-02T14:30:00.000Z`)
///     don't fail the test.
bool _isStructurallyEqual(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) {
    return _isEmptyish(a) && _isEmptyish(b);
  }
  if (a is Map && b is Map) {
    final keys = <Object?>{...a.keys, ...b.keys};
    for (final k in keys) {
      if (!_isStructurallyEqual(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_isStructurallyEqual(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is num && b is num) return a.toDouble() == b.toDouble();
  if (a is String && b is String) {
    // Normalize ISO dates.
    final aDate = DateTime.tryParse(a);
    final bDate = DateTime.tryParse(b);
    if (aDate != null && bDate != null) return aDate.isAtSameMomentAs(bDate);
    return a == b;
  }
  return a == b;
}

bool _isEmptyish(Object? v) {
  if (v == null) return true;
  if (v is String) return v.isEmpty;
  if (v is List) return v.isEmpty;
  if (v is Map) return v.isEmpty;
  return false;
}
