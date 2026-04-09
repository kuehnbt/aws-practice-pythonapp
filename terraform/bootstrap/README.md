# Bootstrap

Run this once per AWS account before CI can deploy anything. Uses local
state because it builds the remote state backend for everything else.

Creates:
1. S3 bucket + DynamoDB table for remote state
2. GitHub Actions OIDC provider
3. Deploy role assumable by GitHub Actions
4. ECR repository

## Prereqs

- AWS CLI with admin on the target account
- Terraform 1.5+
- GitHub org/repo that will deploy from this role

## Apply

```bash
cd terraform/bootstrap
terraform init
terraform apply \
  -var "github_repo=YOUR_ORG/YOUR_REPO" \
  -var "aws_region=us-east-1"
```

## Outputs to GitHub secrets

| Output            | GitHub secret     |
|-------------------|-------------------|
| `tf_state_bucket` | `TF_STATE_BUCKET` |
| `tf_lock_table`   | `TF_LOCK_TABLE`   |
| `gha_role_arn`    | `AWS_ROLE_ARN`    |
| `ecr_repo_url`    | `ECR_REPO_URL`    |

`terraform/app/backend.tf` is a partial config. Values are passed to
`terraform init` via `-backend-config` flags (from the secrets above in CI,
or from `backend.dev.hcl` locally).

For local runs against `terraform/app`:

```bash
cd ../app
cp backend.dev.hcl.example backend.dev.hcl
# edit the values
terraform init -backend-config=backend.dev.hcl
```

## Destroy

Destroy `terraform/app` first, then this module.

```bash
terraform destroy
```
