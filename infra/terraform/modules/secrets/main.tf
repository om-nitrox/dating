###############################################################################
# Secrets module — Secrets Manager placeholders.
#
# Terraform creates the *containers*. The VALUES are seeded out-of-band
# (AWS Console / `aws secretsmanager put-secret-value`) so secrets never
# touch source control or tfvars.
#
# This module deliberately uses `lifecycle { ignore_changes = [secret_string] }`
# in the version resource so that re-applying TF does not blow away a value
# that an operator manually rotated.
###############################################################################

variable "name_prefix" {
  description = "Prefix for all secret names, e.g. 'reverse-match/staging'"
  type        = string
}

locals {
  # The list of secret names every Reverse Match container needs at boot.
  # If you add a new env var to backend/src/config, add it here too.
  secret_names = [
    "JWT_ACCESS_SECRET",
    "JWT_REFRESH_SECRET",
    "MONGO_URI",
    "STRIPE_SECRET_KEY",
    "STRIPE_WEBHOOK_SECRET",
    "CLOUDINARY_CLOUD_NAME",
    "CLOUDINARY_API_KEY",
    "CLOUDINARY_API_SECRET",
    "GOOGLE_CLIENT_ID",
    "SMTP_HOST",
    "SMTP_PORT",
    "SMTP_USER",
    "SMTP_PASS",
    "FIREBASE_SERVICE_ACCOUNT_JSON",  # whole JSON blob, not a path
    "OTP_PEPPER",
    "SENTRY_DSN",
  ]
}

resource "aws_secretsmanager_secret" "this" {
  for_each                = toset(local.secret_names)
  name                    = "${var.name_prefix}/${each.key}"
  description             = "Reverse Match — ${each.key}"
  recovery_window_in_days = 7
}

# Seed each secret with a sentinel value the first time only. Operators
# overwrite via console / CLI; we never overwrite once a real value lands.
resource "aws_secretsmanager_secret_version" "placeholder" {
  for_each      = aws_secretsmanager_secret.this
  secret_id     = each.value.id
  secret_string = "REPLACE_ME"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

output "secret_arns" {
  description = "Map of secret short-name → ARN. ECS task defs reference these."
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}
