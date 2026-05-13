# Observability conventions (Phase 0.9)

This document defines two project-wide conventions:

1. The named metrics exposed via `/metrics` on api (port 5000) and worker (port 9091).
2. The structured-log `event` names used across the backend.

The third piece (CloudWatch log group naming) is documented at the bottom.

## Metrics

All metrics live in [`metrics.js`](./metrics.js). Use the shared registry
imported from this module — do **not** create a separate prom-client
`Registry` elsewhere or `client.register` (the default global one), or
the api + worker dashboards will drift apart.

| Metric                            | Type      | Labels                              | Where it's bumped                                                     |
| --------------------------------- | --------- | ----------------------------------- | --------------------------------------------------------------------- |
| `http_requests_total`             | Counter   | `method`, `route`, `status`         | `httpMetricsMiddleware` in `app.js`                                   |
| `http_request_duration_seconds`   | Histogram | `method`, `route`, `status`         | same middleware                                                       |
| `socket_connections_active`       | Gauge     | —                                   | `socket/index.js` on connect/disconnect                               |
| `socket_events_total`             | Counter   | `event`, `direction` (inbound\|outbound) | `realtime/events.js` (outbound) and `socket/chat.handler.js` (inbound) |
| `job_processed_total`             | Counter   | `queue`, `job`, `status`            | `worker.js` processor callback + listeners                            |
| `job_duration_seconds`            | Histogram | `queue`, `job`                      | `worker.js`                                                           |
| `match_created_total`             | Counter   | —                                   | `services/queue.service.js#accept`                                    |
| `boost_activated_total`           | Counter   | `tier`                              | `services/boost.service.js#activateBoost`                             |
| `otp_sent_total`                  | Counter   | `result` (sent\|throttled\|failed)  | `services/auth.service.js#sendOtp`                                    |

In addition, `prom-client`'s `collectDefaultMetrics` populates the standard
Node/process series (`process_cpu_seconds_total`, `nodejs_eventloop_lag_seconds`,
heap, GC, etc.).

### Adding a new metric

1. Declare it in `metrics.js` with `registers: [register]`.
2. Bump it from the call site — do not pre-create labels you don't need.
3. Update this table.
4. If it's a histogram with a tighter latency profile than the defaults,
   override the `buckets` array.

## Structured logging — `event` names

Every meaningful log line should carry an `event` field with one of the
conventional names below. The name is dot-separated, with the LEFT half
identifying the subsystem and the RIGHT half identifying the action.
Dashboards and alerts subscribe to event names rather than free-text
messages.

| Subsystem | Event                       | Where                                    | Notes                                  |
| --------- | --------------------------- | ---------------------------------------- | -------------------------------------- |
| `auth`    | `auth.otp_sent`             | `auth.service#sendOtp`                   | result=sent counter accompanies        |
| `auth`    | `auth.otp_send_failed`      | `auth.service#sendOtp` (catch path)      | result=failed counter accompanies      |
| `auth`    | `auth.login_success`        | `auth.service#issueTokens`               | covers OTP, Google, refresh paths      |
| `match`   | `match.created`             | `queue.service#accept`                   | bumps `match_created_total`            |
| `message` | `message.sent`              | `message.service#sendMessage`            | once per HTTP or socket send           |
| `boost`   | `boost.activated`           | `boost.service#activateBoost`            | bumps `boost_activated_total{tier}`    |
| `socket`  | `socket.connected`          | `socket/index.js` on connection          | gauge inc                              |
| `socket`  | `socket.disconnected`       | `socket/index.js` on disconnect          | gauge dec                              |
| `job`     | `job.started`               | `worker.js` processor                    |                                        |
| `job`     | `job.completed`             | `worker.js` processor (success)          | with `durationSec`                     |
| `job`     | `job.failed`                | `worker.js` processor (catch + listener) | with `durationSec`                     |
| `queue`   | (forthcoming)               | `services/queue.service.js`              | reserved for queue-domain events       |
| `profile` | (forthcoming)               | `services/profile.service.js`            | reserved for profile-domain events    |

### Rules

- Field name is always `event`, not `eventName` or `type`.
- `event` value is dot-separated `subsystem.action`, lowercase, snake_case.
- Reuse an existing subsystem prefix before inventing a new one.
- New events should also have a corresponding `prom-client` counter when
  the rate matters for dashboards.
- Never put PII in either the metric labels or the log line.

### Adding a new event

1. Pick a subsystem prefix from the list above (or add one with this PR).
2. Use `logger.info({ event: 'subsystem.action', ...context }, 'human message')`.
3. Add a row to the table above.

## CloudWatch log group convention

ECS task definitions write stdout/stderr to CloudWatch. Phase 0.8's
Terraform creates these groups; backend code does **not** create them.
Names match `awslogs-group` in the task definitions:

- `/ecs/reverse-match-api`    — api service (port 5000)
- `/ecs/reverse-match-worker` — worker service (port 9091)

Both share the same `awslogs-stream-prefix: ecs` and `awslogs-region`
(typically `us-east-1`). Pino writes a single JSON object per line, so
CloudWatch Logs Insights queries can filter by `event` directly:

```
fields @timestamp, event, userId, message
| filter event = "auth.login_success"
| stats count() by bin(5m)
```

## Grafana dashboards

JSON definitions are committed at:
- `infra/grafana/api.json`
- `infra/grafana/worker.json`

These are imported by the Grafana provisioner (Terraform-managed). They
are intentionally not pixel-perfect — the goal is dashboards-as-code so
panel changes are reviewable.
