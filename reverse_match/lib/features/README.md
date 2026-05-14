# `lib/features/` — feature module layout

Every feature in the app follows the same vertical-slice pattern:

```
features/<feature>/
├── data/             # Repositories. The ONLY layer allowed to touch Dio.
│   └── <feature>_repository.dart
├── domain/           # (optional) Plain-Dart value objects, business rules.
└── presentation/
    ├── providers/    # Riverpod state notifiers / providers.
    └── screens/      # Widgets / pages.
```

## Data flow

```
Widget -> Notifier/Provider -> Repository -> ReverseMatchApiClient -> Dio
                                                                    ^
                                                                    |
                                            (auth-refresh, dummy, retry interceptors)
```

- **Widgets** read state from Riverpod providers. They MUST NOT touch Dio
  directly.
- **Notifiers/providers** call repository methods. They consume the
  `ApiResult<T>` sealed result type from `core/network/api_result.dart`.
- **Repositories** are the only layer that talks to the network. They:
  - Accept a generated API class (e.g. `MessagesApi`) — not raw Dio — via
    constructor injection.
  - Return legacy models from `lib/shared/models/` via the adapters in
    `lib/shared/models/_api_adapters.dart`, so widget code is unaffected
    by the migration to the generated client.
  - Wrap responses in `ApiResult<T>` (`Success` | `Failure`) so callers
    can do exhaustive switch handling without try/catch noise.

## Adding a new feature

1. Create `features/<feature>/data/<feature>_repository.dart`.
2. Add a `Provider<...Repository>` at the top of that file that reads the
   relevant sub-API off `apiClientProvider` (from
   `core/network/api_client_provider.dart`).
3. Add presentation-layer providers under `features/<feature>/presentation/providers/`
   that consume the repository.
4. Build screens that read providers — never raw Dio.

## Rules enforced by review

- Zero `dio.get|post|put|delete|patch|request` calls outside `*/data/`
  directories or `core/network/`.
- Zero `ref.read(dioProvider)` / `ref.watch(dioProvider)` calls outside
  `*/data/` or `core/network/`.
- Every new endpoint goes through the generated `ReverseMatchApiClient`
  (regenerate from `docs/api/openapi.yaml`). Direct Dio is allowed inside
  `data/` only as a transitional escape hatch for endpoints not yet in
  the spec; mark with a `TODO(spec)` comment.

## See also

- `core/network/api_client_provider.dart` — singleton `ReverseMatchApiClient`.
- `core/network/dio_client.dart` — interceptors (auth refresh, retry, dummy).
- `shared/models/_api_adapters.dart` — generated → legacy model adapters.
- `ARCHITECTURE_REVIEW.md` (repo root) — full Phase 1 plan including 1.8.
