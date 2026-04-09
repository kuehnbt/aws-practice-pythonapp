# Partial backend config. Bucket, table, and region are supplied at init
# time via -backend-config flags (from GitHub Actions secrets in CI, or
# backend.dev.hcl locally).
terraform {
  backend "s3" {}
}
