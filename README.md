# aws-practice-pythonapp

Minimal FastAPI service deployed to AWS ECS Fargate via GitHub Actions + Terraform.

The app is intentionally small. The point of this repo is the **pipeline, IaC,
and security practices** around it.

## Architecture

```
          ┌───────────────┐     push     ┌──────────┐
 dev  ──▶ │ GitHub (main) │ ───────────▶ │ Actions  │
          └───────────────┘              └────┬─────┘
                                              │ OIDC
                                              ▼
                                       ┌──────────────┐
                                       │ AWS account  │
                                       └──────┬───────┘
                                              │
      ┌────────┐    ┌──────┐    ┌─────────────┴──────────────┐    ┌────────────┐
user→ │  ALB   │──▶ │ ECS  │──▶ │ Fargate task (FastAPI app) │──▶ │ CloudWatch │
      │  :80   │    │ svc  │    └────────────────────────────┘    │  Logs +    │
      └────────┘    └──────┘                                       │  Alarms    │
                                                                   └────────────┘
```

## Repo Layout

```
.
├── src/app/
├── tests/
├── Dockerfile
├── terraform/
│   ├── bootstrap/
│   └── app/ 
├── .github/workflows/
│   ├── pr.yml
│   ├── deploy.yml
│   └── security.yml
├── Makefile
├── pyproject.toml
├── HELPER.md
├── PROMPT.md
└── README.md (you are here)
```

## Quickstart

```bash
make install
make check
make build-image
make run-local
```

Endpoints: `GET /`, `GET /healthz`, `GET /info`.

## One-Time Bootstrap

Before CI can deploy anything, you need the state backend, OIDC provider, and
ECR repo. These are in `terraform/bootstrap/` and use **local state**. Apply
them once from your workstation with AWS credentials for the target account:

```bash
cd terraform/bootstrap
terraform init
terraform apply \
  -var "github_repo=YOUR_ORG/YOUR_REPO" \
  -var "aws_region=us-east-1"
```

Then add GitHub Actions repository secrets (nothing to hand-edit in source
files — `terraform/app/backend.tf` uses **partial backend config** and reads
these at `init` time):

| Secret            | Source (bootstrap output) |
|-------------------|---------------------------|
| `AWS_ROLE_ARN`    | `gha_role_arn`            |
| `ECR_REPO_URL`    | `ecr_repo_url`            |
| `TF_STATE_BUCKET` | `tf_state_bucket`         |
| `TF_LOCK_TABLE`   | `tf_lock_table`           |

Also add a GitHub Environment named `prod` with required reviewers and scope
these secrets to that environment.

For local Terraform runs against `terraform/app/`, copy the example partial
config and fill it in:
```bash
cd terraform/app
cp backend.dev.hcl.example backend.dev.hcl   # gitignored
# edit the values from the bootstrap outputs
terraform init -backend-config=backend.dev.hcl
```

See [`terraform/bootstrap/README.md`](terraform/bootstrap/README.md) for detail.

## Deploy

Every push to `main`:
1. Builds the image, tags it with the git SHA, pushes to ECR
2. Fails the build on HIGH/CRITICAL trivy findings
3. `terraform apply` against `terraform/app/` with the new image URI
4. Curls `/healthz` on the ALB — exits non-zero if it doesn't return 200

Pull requests get:
- ruff lint + format check
- mypy
- pytest with coverage
- pip-audit
- gitleaks
- trivy (on a PR-built image)
- `terraform fmt`, `validate`, `tfsec`
- `terraform plan` posted as a PR comment

## Cost

| Resource           | Monthly     |
|--------------------|-------------|
| Fargate 0.25/0.5   | ~$9         |
| ALB                | ~$16 + LCU  |
| CloudWatch Logs    | <$1         |
| ECR                | <$1         |
| **Total**          | **~$25-30** |

No NAT Gateway (public subnet tradeoff). Adding one NAT would push this to ~$60.

## Teardown

```bash
# From your workstation (CI doesn't own destroy)
cd terraform/app
terraform destroy

cd ../bootstrap
terraform destroy
```

Destroy `app` first, then `bootstrap`. The bucket has `force_destroy = false`
on purpose — if destroy fails because of objects in the state bucket, that's
deliberate friction to prevent accidents.

## Runbook

**Alarm: `bgs-hello-dev-unhealthy-hosts`**
1. Check ECS service events: `aws ecs describe-services --cluster bgs-hello-dev --services bgs-hello-dev`
2. Check task stopped reasons: `aws ecs list-tasks ... --desired-status STOPPED`
3. Check container logs: `aws logs tail /ecs/bgs-hello-dev --since 15m`
4. Common causes: healthcheck path wrong, container crash loop, image pull
   failure, SG misconfigured

**Alarm: `bgs-hello-dev-target-5xx`**
1. Look at logs for stack traces
2. Check if a recent deploy correlates — roll back if yes
3. If persistent, open an incident; the service is user-impacting

**CI Test**
Test this