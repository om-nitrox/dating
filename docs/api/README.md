# API Contract — `docs/api/`

This directory holds the single source of truth for the Reverse Match backend↔frontend
contract.

| File | Purpose |
|---|---|
| `openapi.yaml` | OpenAPI 3.1 — every REST endpoint, request/response shape, and shared schema. |
| `asyncapi.yaml` | AsyncAPI 2.6 — every Socket.IO event the client publishes or subscribes to. |
| `README.md` | This file. |

The previous Markdown spec (`BACKEND_API.md`) is retired. Anything not captured in
`openapi.yaml` / `asyncapi.yaml` is not part of the contract.

## How to update the spec when adding an endpoint

1. **Add to the spec first**, not the code. Open `openapi.yaml`, find the right tag
   section (or add one), and add a path + operation. Reuse a `components.schema` via
   `$ref` rather than inlining a body.
2. **Lint locally**: `npm run lint:openapi` at the repo root. CI runs the same command.
3. **Open the PR with the spec change**. Reviewers verify the spec change first; the
   backend implementation and Flutter consumer changes follow.
4. **Codegen** (Phase 0.2 / 0.3): regenerate Dart models in `reverse_match/lib/api/` and
   Joi/zod validators in `backend/src/validators/`. CI will fail if generated code is
   out of sync with the spec.

For Socket.IO event changes, edit `asyncapi.yaml` and the same rules apply.

## Validation in CI

The GitHub Actions workflow at `.github/workflows/ci.yml` runs the `openapi-lint` job
on every push and pull request:

```yaml
- name: Install deps
  run: npm ci
- name: Lint OpenAPI + AsyncAPI specs
  run: npm run lint:openapi
```

The lint task fails on any Spectral **error**. Warnings are surfaced in the job log but
do not fail the build. The active ruleset lives at `.spectral.yaml`.

## Drift detection

Today the spec is human-maintained. Phase 0.2 (Dart model codegen) and Phase 0.3
(validator codegen) will consume `openapi.yaml` directly, which makes contract drift
impossible to ship silently: a missing schema → no model → frontend won't compile; a
missing validator → 400 at the boundary.

**TODO**: in a follow-up, add a CI job that introspects the live Express route table
(at boot, in test mode) and fails if any route is not documented in `openapi.yaml`.
Sketch: a Jest integration test that boots the app, walks `app._router.stack`,
extracts `{method, path}` tuples, normalizes Express `:param` → OpenAPI `{param}`, and
diffs against the spec's `paths` keys. Same idea for Socket.IO event names.

## Consumers of these files

| Consumer | How it reads the spec |
|---|---|
| **`packages/api-client-dart`** (Phase 0.2) | Dart models + Dio-based API client consumed by the Flutter app at `reverse_match/`. Today hand-written from the spec; `openapi-config.yaml` + `tool/codegen.{sh,ps1}` wire `openapi_generator` for future regen. See `packages/api-client-dart/README.md`. |
| Backend validators (Phase 0.3) | Codegen step produces `backend/src/validators/_generated/*.js`. |
| Backend taxonomies (Phase 0.4) | Enum schemas re-exported as JS constants. |
| Contract tests (Phase 2.10) | Pact files or shared JSON fixtures validated against the schemas in both runtimes. |
| Future API docs site | `redocly preview-docs docs/api/openapi.yaml` for browsable docs. |
| Retool / future admin web UI | Calls the REST API directly — no generated client needed. |

### Drift detection in CI

The CI workflow at `.github/workflows/ci.yml` (`openapi-codegen-drift` job) hashes
`docs/api/openapi.yaml` on every PR and compares it to the hash stored at
`packages/api-client-dart/SPEC_HASH`. If they diverge — i.e. the spec changed
but the Dart client wasn't regenerated/updated — the build fails. Update both
in the same PR (see `packages/api-client-dart/README.md > "Adding a new
endpoint"`).

## Open ambiguities flagged in the spec

Anything captured as `**TODO**:` inside a `description:` is a contract ambiguity that
needs a follow-up decision. Current set:

- `/queue` pagination — full set returned today, no pagination documented.
- `SendMessageRequest.text` max length — spec doc does not specify; spec assumes 2000.
- `UserModel.politics` — free-form string in the spec doc but the ideal-match scorer
  expects an enumerated set. Decide before codegen.
- `/profile/selfie` automatic face-match path — when an auto-verifier ships, the
  response may return `verified: true` immediately for high-confidence matches.
