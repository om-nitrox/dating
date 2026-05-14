import 'package:flutter_test/flutter_test.dart';
import 'package:reverse_match/shared/models/user_model.dart';

void main() {
  group('UserModel.fromJson', () {
    test('parses a minimal payload (id only) without throwing', () {
      final user = UserModel.fromJson({'_id': 'abc123'});
      expect(user.id, 'abc123');
      expect(user.name, isNull);
      expect(user.age, isNull);
      expect(user.photos, isEmpty);
      expect(user.pronouns, isEmpty);
      expect(user.isProfileComplete, isFalse);
      expect(user.isVerified, isFalse);
      expect(user.boostLevel, 'none');
    });

    test('accepts `id` as well as `_id` (REST vs Mongo)', () {
      final user = UserModel.fromJson({'id': 'fromShortKey'});
      expect(user.id, 'fromShortKey');
    });

    test('parses a complete payload', () {
      final user = UserModel.fromJson({
        '_id': 'user-1',
        'email': 'alice@example.com',
        'name': 'Alice',
        'age': 27,
        'gender': 'female',
        'pronouns': ['she', 'her'],
        'orientation': ['straight'],
        'bio': 'hello world',
        'interests': ['hiking', 'coffee'],
        'photos': [
          {'url': 'https://cdn/1.jpg', 'publicId': 'pub1'},
        ],
        'height': 170,
        'isVerified': true,
        'isProfileComplete': true,
        'boostLevel': 'gold',
      });

      expect(user.id, 'user-1');
      expect(user.email, 'alice@example.com');
      expect(user.name, 'Alice');
      expect(user.age, 27);
      expect(user.gender, 'female');
      expect(user.pronouns, ['she', 'her']);
      expect(user.orientation, ['straight']);
      expect(user.bio, 'hello world');
      expect(user.interests, ['hiking', 'coffee']);
      expect(user.photos, hasLength(1));
      expect(user.photos.first.url, 'https://cdn/1.jpg');
      expect(user.height, 170);
      expect(user.isVerified, isTrue);
      expect(user.isProfileComplete, isTrue);
      expect(user.boostLevel, 'gold');
    });

    test('parses ISO-8601 dob into a DateTime', () {
      final user = UserModel.fromJson({
        '_id': 'u',
        'dob': '1998-04-15T00:00:00.000Z',
      });
      expect(user.dob, isNotNull);
      expect(user.dob!.year, 1998);
      expect(user.dob!.month, 4);
      expect(user.dob!.day, 15);
    });

    test('tolerates missing / null list fields without crashing', () {
      final user = UserModel.fromJson({
        '_id': 'u',
        'pronouns': null,
        'interests': null,
        'photos': null,
        'languages': null,
      });
      expect(user.pronouns, isEmpty);
      expect(user.interests, isEmpty);
      expect(user.photos, isEmpty);
      expect(user.languages, isEmpty);
    });
  });
}
