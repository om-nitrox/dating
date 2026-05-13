# Staging Deployment Runbook

Target: AWS ECS Fargate, single-region, MongoDB Atlas, ElastiCache Redis.

## Pre-requisites (one-time)

- AWS account with billing alarm configured
- IAM user with admin access (only for bootstrap; CI uses an OIDC role)
- MongoDB Atlas account + project + M10+ cluster
- Cloudinary, Stripe, Firebase, Google OAuth client, SMTP provider — all
  set up out-of-band; credentials in hand
- Domain name (Route53 zone or external) for `staging-api.<your-domain>`
- Terraform CLI >= 1.6.0
- `aws` CLI v2, `gh` CLI

## Manual one-time AWS bootstrap (before any Terraform)

- [ ] Create S3 bucket for tfstate (`reverse-match-tfstate-<suffix>`),
      versioning + encryption ON
- [ ] Create DynamoDB table `reverse-match-tflock` for state locking
- [ ] Create OIDC identity provider for GitHub Actions:
      `arn:aws:iam::<acct>:oidc-provider/token.actions.githubusercontent.com`
- [ ] Create IAM role `reverse-match-github-cd` with trust policy limited to
      this repo's `main` branch + `staging` environment. Attach policies:
      `AmazonEC2ContainerRegistryPowerUser`, `AmazonECS_FullAccess`
      (tighten in Phase 1.16 to least-privilege)
- [ ] Register the staging domain / create Route53 hosted zone
- [ ] Request ACM cert for `staging-api.<your-domain>` (DNS validation)

See `infra/terraform/README.md` for the exact CLI commands.

## Terraform bootstrap (first-time, per-environment)

Apply order from `infra/terraform/staging/`:

1. `terraform init` (after replacing `TODO-*` placeholders in `main.tf`)
2. `terraform plan -out tfplan`
3. `terraform apply tfplan`

Module order if applying piecemeal (with `-target`):

1. `module.network`
2. `module.ecr`
3. `module.secrets`
4. `module.redis`
5. `module.ecs`

## Seeding secrets

After Terraform creates the Secrets Manager placeholders, write real values:

```bash
aws secretsmanager put-secret-value \
  --secret-id reverse-match/staging/<NAME> \
  --secret-string "<value>"
```

Required: `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `MONGO_URI`,
`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `CLOUDINARY_CLOUD_NAME`,
`CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`, `GOOGLE_CLIENT_ID`,
`SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`,
`FIREBASE_SERVICE_ACCOUNT_JSON` (whole JSON blob), `OTP_PEPPER`,
`SENTRY_DSN`.

## GitHub configuration (one-time)

**Repository secrets:**

| Name | Value |
|---|---|
| `AWS_ROLE_TO_ASSUME` | ARN of `reverse-match-github-cd` IAM role |

**Repository variables:**

| Name | Value |
|---|---|
| `AWS_REGION` | e.g. `us-east-1` |
| `AWS_ACCOUNT_ID` | 12-digit AWS account id |
| `STAGING_ECS_CLUSTER` | output `ecs_cluster_name` from Terraform |
| `STAGING_API_SERVICE` | output `api_service_name` from Terraform |
| `STAGING_WORKER_SERVICE` | output `worker_service_name` from Terraform |
| `STAGING_API_URL` | `https://staging-api.<your-domain>` |

**Environment `staging`** (Settings → Environments → New): add a required
reviewer so deploys pause for manual approval. This is the gate that
prevents an accidental push to `main` from going live.

## Day-2: Deploy

Normal flow:

```bash
git push origin main
```

This triggers `.github/workflows/cd.yml`:

1. `build-and-push` — builds api + worker images, pushes to ECR with tags
   `:sha-<commit>` and `:staging`
2. `deploy-staging` — pauses for manual approval (staging environment),
   then runs `aws ecs update-service --force-new-deployment` for both
   services
3. `smoke-test` — `curl /health` + `/api/v1/config`, expects 200

## Rollback

When staging breaks, redeploy a previous image **without rebuilding**:

```bash
gh workflow run cd.yml \
  -f deploy_only=true \
  -f image_tag=sha-<previous-good-commit-sha>
```

The `deploy_only=true` input skips `build-and-push` and runs only
`deploy-staging` + `smoke-test` with the supplied tag. Find previous tags:

```bash
aws ecr list-images --repository-name reverse-match-api \
  --filter tagStatus=TAGGED \
  --query 'imageIds[?starts_with(imageTag, `sha-`)].imageTag'
```

## Logs

- CloudWatch log group `/ecs/reverse-match-staging-api`
- CloudWatch log group `/ecs/reverse-match-staging-worker`
- Container Insights metrics: `AWS/ECS/ContainerInsights/reverse-match-staging-cluster`

```bash
aws logs tail /ecs/reverse-match-staging-api --follow
aws logs tail /ecs/reverse-match-staging-worker --follow
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Smoke test fails immediately | ALB not wired yet (Phase-1.16) | Expected for now — verify task is `RUNNING` via `aws ecs describe-services` |
| `deploy-staging` fails with `AccessDenied` | OIDC role lacks ECS perms | Re-check trust policy + attached policies |
| Worker image push warning | `Dockerfile.worker` not in repo yet | Will resolve once parallel agent lands the worker scaffolding |
| Task stuck `PROVISIONING` | Subnet has no NAT route / Secrets Manager unreachable | Check `module.network` NAT gateway state |
| Container exits `task failed essential container in task` | Secret value still `REPLACE_ME` | Seed real values via `aws secretsmanager put-secret-value` |
| `services-stable` wait times out | App boots slowly / health check failing | Check `/health` is responding on port 5000 inside the container |

## What's NOT in staging yet (gaps to close before production)

- Real public URL — ALB + Route53 + ACM (Phase-1.16)
- Auto-scaling — manual desired-count for now
- Multi-AZ Redis — single node for staging cost
- Alarms / paging — CloudWatch alarms not yet defined
- Atlas peering — see `infra/terraform/modules/network` TODO
