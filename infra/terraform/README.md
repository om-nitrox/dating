# Reverse Match — Terraform (AWS)

This directory holds the infrastructure-as-code scaffold for Reverse Match's
AWS deployment. **It is a stub.** The module shapes are real and the
variables wire up correctly, but several resources are intentionally not yet
written. See "What is intentionally missing" below before running `apply`.

## Layout

```
infra/terraform/
  staging/                  # entry point for the staging env
    main.tf
    terraform.tfvars.example
  modules/
    network/                # VPC, subnets, NAT, security groups
    ecr/                    # ECR repositories (api + worker)
    ecs-fargate/            # ECS cluster, task defs, services
    elasticache/            # Redis (cluster-mode-disabled, single node)
    secrets/                # Secrets Manager placeholders
```

## Bootstrap (one-time, manual)

Terraform's S3+DynamoDB remote state needs to exist **before** `terraform
init`. Create it with the AWS Console or these CLI calls:

```bash
# Replace REGION and unique BUCKET / TABLE names.
aws s3api create-bucket \
  --bucket reverse-match-tfstate-<unique-suffix> \
  --region <REGION>

aws s3api put-bucket-versioning \
  --bucket reverse-match-tfstate-<unique-suffix> \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket reverse-match-tfstate-<unique-suffix> \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws dynamodb create-table \
  --table-name reverse-match-tflock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region <REGION>
```

Then edit `staging/main.tf` and replace the `TODO-*` placeholders in the
`backend "s3" { ... }` block with the real bucket / region / table names.

## Apply order

Terraform handles inter-module dependencies, but if you apply in stages
(useful for cost/scope review), do it in this order:

1. `module.network`
2. `module.ecr`
3. `module.secrets`
4. `module.redis`
5. `module.ecs`

Run from `infra/terraform/staging/`:

```bash
cp terraform.tfvars.example terraform.tfvars  # then edit
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

## After `apply`

Seed the Secrets Manager entries with real values. Terraform created
empty placeholders (`REPLACE_ME`) and is configured to never overwrite
once an operator rotates the value:

```bash
aws secretsmanager put-secret-value \
  --secret-id reverse-match/staging/JWT_ACCESS_SECRET \
  --secret-string "$(openssl rand -hex 32)"

aws secretsmanager put-secret-value \
  --secret-id reverse-match/staging/MONGO_URI \
  --secret-string "mongodb+srv://user:pass@cluster.mongodb.net/reverse_match_staging"

# ...repeat for every secret listed in modules/secrets/main.tf::local.secret_names
```

Then push the first images to the new ECR repos (the GitHub `cd.yml`
workflow does this automatically once you set the repo variables and
secrets — see `docs/deployment/staging.md`).

## What is intentionally missing (Phase-1.16 work)

These are **deliberate stubs**. Don't be surprised when they're not there:

| Component | Why deferred | Notes |
|---|---|---|
| ALB + ACM cert + Route53 | No domain yet | Without this, ECS api service runs but has no public URL. Smoke test in `cd.yml` will fail until this lands. |
| MongoDB Atlas peering | Atlas project not created | Decide PrivateLink vs VPC peering. Wire in `modules/network/main.tf` (see TODO marker). |
| Autoscaling policies | No real load yet | Add target-tracking on CPU/mem in ECS module. |
| CloudWatch alarms + SNS | No oncall rotation yet | 5xx rate, deploy-circuit-breaker, queue depth. |
| Production environment | Phase 1 scope | `infra/terraform/production/` will copy `staging/` with prod sizing. |
| Atlas (database itself) | Not managed by AWS TF | Use the MongoDB Atlas Terraform provider in a separate state file, OR manage via Atlas UI for staging. |
| Cloudinary / Firebase / Stripe | External SaaS | Provisioned outside TF. Credentials seeded into Secrets Manager. |
| Bastion / SSM access | No ops need yet | Will add SSM Session Manager when ops debugging requires it. |

## NOT in this Terraform (and never will be)

- **MongoDB Atlas cluster** — managed via Atlas UI or the `mongodbatlas`
  Terraform provider in its own state file. Keeping AWS state separate
  from SaaS state means an Atlas outage can't lock the AWS pipeline.
- **Cloudinary, Firebase, Stripe, SMTP, Sentry** — set up via their
  consoles. Credentials land in AWS Secrets Manager.
- **Domain registration / Route53 zone creation** — done once, manually.
  Only individual records belong in TF.

## Destroying staging

```bash
cd infra/terraform/staging
terraform destroy
```

Caveats:
- Secrets Manager secrets have a `recovery_window_in_days = 7`. They are
  soft-deleted; restore with `aws secretsmanager restore-secret`.
- ECR repos with images in them will refuse to delete (`force_delete = false`).
  Empty them first or flip `force_delete = true` in `modules/ecr/main.tf`.
- The S3 state bucket and DynamoDB lock table are **not** managed by TF and
  must be removed by hand.
