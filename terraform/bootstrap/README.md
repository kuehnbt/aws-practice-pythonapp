# Bootstrap (one-time, run locally by a human)

Creates the resources that CI needs before it can run:

1. S3 bucket + DynamoDB table for Terraform remote state
2. IAM OIDC provider for GitHub Actions
3. IAM role that GitHub Actions assumes via OIDC (`github-actions-bgs-hello`)
4. ECR repository (so CI has somewhere to push images)

Uses **local state** — this is the chicken-and-egg layer for everything else.

## Prereqs
- AWS CLI configured with an account you can admin
- Terraform 1.5+
- You know the GitHub org/repo this will deploy from

## Apply

```bash
cd terraform/bootstrap
terraform init
terraform apply \
  -var "github_repo=YOUR_ORG/YOUR_REPO" \
  -var "aws_region=us-east-1"
```

Outputs (all go into **GitHub Actions secrets**, not source files):

| Output            | GitHub secret     | Used by                                 |
|-------------------|-------------------|-----------------------------------------|
| `tf_state_bucket` | `TF_STATE_BUCKET` | `terraform init -backend-config=...`    |
| `tf_lock_table`   | `TF_LOCK_TABLE`   | `terraform init -backend-config=...`    |
| `gha_role_arn`    | `AWS_ROLE_ARN`    | `aws-actions/configure-aws-credentials` |
| `ecr_repo_url`    | `ECR_REPO_URL`    | image push + PR plan placeholder tag    |

`terraform/app/backend.tf` uses a **partial backend config** — bucket/table/
region are supplied at `init` time via `-backend-config` flags from these
secrets. Nothing to hand-edit in the repo.

For local Terraform runs against `terraform/app/`:
```bash
cd ../app
cp backend.dev.hcl.example backend.dev.hcl   # gitignored; fill in from outputs
terraform init -backend-config=backend.dev.hcl
```

## Destroy
Destroy last — only after `terraform/app` is destroyed.
```bash
terraform destroy
```
