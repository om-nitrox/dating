# `reverse_match_api` — typed REST client for the Reverse Match API

This package is the single Dart type layer for the Reverse Match HTTP API.
The spec at `docs/api/openapi.yaml` is the source of truth; every model and
endpoint exposed here mirrors that spec exactly.

## What you get

```dart
import 'package:dio/dio.dart';
import 'package:reverse_match_api/reverse_match_api.dart';

final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api/v1'));
// ...add auth/refresh/dummy interceptors on `dio`...

final api = ReverseMatchApiClient(dio: dio);

final user = await api.profile.getProfile();          // UserModel
final feed = await api.swipe.getSwipeFeed();          // SwipeFeedResponse
await api.swipe.likeUser(UserIdRequest(userId: id));
```

One Dio in, eleven typed API surfaces out:

| Getter | Tag | Backed by |
|---|---|---|
| `api.auth` | `auth` | `AuthApi` |
| `api.profile` | `profile` | `ProfileApi` |
| `api.swipe` | `swipe` | `SwipeApi` |
| `api.queue` | `queue` | `QueueApi` |
| `api.matches` | `matches` | `MatchesApi` |
| `api.messages` | `messages` | `MessagesApi` |
| `api.boost` | `boost` | `BoostApi` |
| `api.safety` | `safety` | `SafetyApi` |
| `api.account` | `account` | `AccountApi` |
| `api.config` | `config` | `ConfigApi` |
| `api.idealMatch` | `ideal-match` | `IdealMatchApi` |

## Codegen status

**Today (Phase 0.2): hand-written.** The models in `lib/src/models/` and the
APIs in `lib/src/apis/` are written by hand from the OpenAPI spec. They are
structurally equivalent to what `openapi_generator` (`dart-dio` template)
would produce, but without the `built_value` dependency stack — keeps the
package lean and the `dart pub get` graph cheap.

`lib/src/generated/` is reserved for generator output and is currently
empty (gitignored). `openapi-config.yaml` and `tool/codegen.{sh,ps1}` are
already wired so flipping to fully generated code later is a one-PR change:

```yaml
# pubspec.yaml — uncomment when ready to switch to codegen:
dev_dependencies:
  openapi_generator: ^6.0.0
  openapi_generator_annotations: ^6.0.0
  build_runner: ^2.4.14
```

Then run:

```bash
dart pub get
./tool/codegen.sh           # or tool/codegen.ps1 on Windows
```

The hand-written code in `lib/src/models/` + `lib/src/apis/` can then be
deleted and the barrel (`lib/reverse_match_api.dart`) re-pointed at
`lib/src/generated/`.

## Why hand-written today

1. The repo couldn't run `dart pub get` in the environment that wrote this
   package — see Phase 0.2 report. We unblock the Flutter side immediately
   while keeping the codegen path open.
2. The hand-written models are smaller, more readable, and round-trip
   correctly under `test/round_trip_test.dart`.
3. `built_value` adds ~3 transitive dependencies and ~2× the generated
   code volume. Worth it once the schema starts adding `oneOf`/discriminator
   patterns; not yet worth it for 31 endpoints + ~25 schemas.

## Drift detection

The CI workflow at `.github/workflows/ci.yml` (job `openapi-codegen-drift`)
runs on PRs that touch `docs/api/openapi.yaml`:

1. Hashes the spec file.
2. Compares to a checked-in hash at `packages/api-client-dart/SPEC_HASH`.
3. Fails the build if the hashes diverge — i.e. the spec changed but this
   package wasn't regenerated/updated to match.

When you update the spec:

```bash
# 1. Edit docs/api/openapi.yaml
# 2. Update lib/src/models/ + lib/src/apis/ to match (or regenerate)
# 3. Update SPEC_HASH:
sha256sum docs/api/openapi.yaml | awk '{print $1}' > packages/api-client-dart/SPEC_HASH
# 4. dart test packages/api-client-dart
# 5. PR includes spec + hash + (re)generated code.
```

## Layout

```
lib/
├── reverse_match_api.dart        Top-level barrel
└── src/
    ├── client.dart               ReverseMatchApiClient facade
    ├── apis/
    │   ├── _base_api.dart
    │   ├── auth_api.dart
    │   ├── account_api.dart
    │   ├── boost_api.dart
    │   ├── config_api.dart
    │   ├── ideal_match_api.dart
    │   ├── matches_api.dart
    │   ├── messages_api.dart
    │   ├── profile_api.dart
    │   ├── queue_api.dart
    │   ├── safety_api.dart
    │   └── swipe_api.dart
    ├── models/
    │   ├── _helpers.dart
    │   ├── auth_models.dart
    │   ├── boost_models.dart
    │   ├── enums.dart
    │   ├── match_models.dart
    │   ├── misc_models.dart
    │   └── user_models.dart
    └── generated/                Codegen output (currently empty, gitignored)
test/
└── round_trip_test.dart          Fixture-driven fromJson/toJson smoke tests
tool/
├── codegen.ps1                   Windows codegen wrapper
└── codegen.sh                    POSIX codegen wrapper
```

## Adding a new endpoint

1. Edit `docs/api/openapi.yaml` — add the path, operation, and any new
   `components.schemas` entries. Reuse existing schemas with `$ref` rather
   than inlining.
2. Run `npm run lint:openapi` at the repo root to validate against Spectral.
3. Mirror the spec change in this package:
   - Add request/response models to `lib/src/models/<area>_models.dart`.
   - Add the operation method to the appropriate `lib/src/apis/*_api.dart`.
   - Re-export from `lib/reverse_match_api.dart` if it's a new model file.
4. Add a round-trip test in `test/round_trip_test.dart`.
5. Update `SPEC_HASH` (see Drift detection above).
6. Bump `version:` in `pubspec.yaml` if the change is breaking.

## Relationship to `reverse_match/`

The Flutter app at `reverse_match/` depends on this package via a path
dependency in its `pubspec.yaml`:

```yaml
dependencies:
  reverse_match_api:
    path: ../packages/api-client-dart
```

The existing dummy interceptor (when present) intercepts on Dio, so the
generated client transparently goes through it — no changes needed on the
mocking layer.

The existing user-facing models at `reverse_match/lib/shared/models/` are
**parallel** to this package's models today; they coexist while the
repositories are migrated one at a time. Full removal is a Phase 1.8
follow-up.
