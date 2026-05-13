// Adapters that convert generated (`reverse_match_api`) models to the
// existing user-facing models in `lib/shared/models/`.
//
// Phase 0.2 intent: keep the existing models as the public surface for
// widgets/notifiers so this migration is non-breaking. Phase 1.8 will swap
// the public surface to the generated models and delete this file.
//
// We round-trip through JSON rather than maintaining hand-mapped fields
// because:
//   1. Both sides already have battle-tested `fromJson` paths.
//   2. The JSON contract is the single source of truth — agreeing on JSON
//      means we agree on data, irrespective of class shape drift.
//   3. The conversion runs on response objects (typically <50 KB), not in
//      a hot loop, so the cost is negligible compared to network latency.

import 'package:reverse_match_api/reverse_match_api.dart' as api;

import 'like_model.dart';
import 'match_model.dart';
import 'message_model.dart';
import 'user_model.dart';

extension ApiUserModelAdapter on api.UserModel {
  /// Convert the generated `UserModel` to the legacy `UserModel` used by
  /// the rest of the Flutter app.
  UserModel toLegacy() => UserModel.fromJson(toJson());
}

extension ApiMatchModelAdapter on api.MatchModel {
  MatchModel toLegacy() => MatchModel.fromJson(toJson());
}

extension ApiMessageModelAdapter on api.MessageModel {
  MessageModel toLegacy() => MessageModel.fromJson(toJson());
}

extension ApiLikeModelAdapter on api.LikeModel {
  LikeModel toLegacy() => LikeModel.fromJson(toJson());
}
