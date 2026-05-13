// Top-level barrel for the `reverse_match_api` package.
//
// Re-exports the typed API client, every per-tag API class, and every
// model schema so consumers can write `import 'package:reverse_match_api/reverse_match_api.dart';`
// and have everything in scope.
//
// Spec source: `docs/api/openapi.yaml`. Regenerate via `tool/codegen.ps1`
// (Windows) or `tool/codegen.sh` (POSIX) once the openapi_generator
// dev_dependency is enabled. See package README.

library reverse_match_api;

// Facade
export 'src/client.dart';

// APIs — one per OpenAPI tag.
export 'src/apis/auth_api.dart';
export 'src/apis/profile_api.dart';
export 'src/apis/swipe_api.dart';
export 'src/apis/queue_api.dart';
export 'src/apis/matches_api.dart';
export 'src/apis/messages_api.dart';
export 'src/apis/boost_api.dart';
export 'src/apis/safety_api.dart';
export 'src/apis/account_api.dart';
export 'src/apis/config_api.dart';
export 'src/apis/ideal_match_api.dart';

// Models — split by domain for readability; everything re-exported flat.
export 'src/models/enums.dart';
export 'src/models/user_models.dart';
export 'src/models/auth_models.dart';
export 'src/models/match_models.dart';
export 'src/models/boost_models.dart';
export 'src/models/misc_models.dart';
