# aws-practice-pythonapp

Minimal FastAPI service deployed to AWS ECS Fargate via GitHub Actions + Terraform.

The app is intentionally small. The point of this repo is the **pipeline, IaC,
and security practices** around it.

## Architecture

```
          ┌───────────────┐     push     ┌──────────┐
 dev  ──▶ │ GitHub (main) │ ───────────▶ │ Actions  │
          └───────────────┘              └────┬─────┘
                                              │ OIDC (no long-lived keys)
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
├── src/app/                    # FastAPI app (~40 lines)
├── tests/                      # pytest for the app
├── Dockerfile                  # multi-stage, non-root, healthcheck
├── terraform/
│   ├── bootstrap/              # ONE-TIME: state backend + OIDC + ECR
│   └── app/                    # applied by CI: VPC/ALB/ECS/logs/alarms
├── .github/workflows/
│   ├── pr.yml                  # lint/test/audit/scan/plan-on-PR
│   ├── deploy.yml              # build/push/apply/smoke-test
│   └── security.yml            # weekly rescan, opens issue on findings
├── Makefile
├── pyproject.toml
├── HELPER.md
├── PROMPT.md
└── README.md (you are here)
```

## Quickstart (local dev)

```bash
make install          # venv + pip install -e ".[dev]"
make check            # lint + type + test + audit
make build-image      # docker build .
make run-local        # localhost:8080
```

Endpoints: `GET /`, `GET /healthz`, `GET /info`.

## One-Time Bootstrap (human-operated)

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

## Deploy (automatic on merge to main)

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

## Security Practices

| Control                  | Implementation                                       |
|--------------------------|------------------------------------------------------|
| No long-lived AWS keys   | GitHub OIDC → IAM role, trust scoped to repo + ref   |
| Least-privilege task role | Empty by default — policies added when app needs them |
| Image scanning           | trivy in PR + deploy + weekly rescan; fail on H/C    |
| Dep scanning             | pip-audit in PR + weekly                             |
| Secret scanning          | gitleaks on every PR                                 |
| IaC scanning             | tfsec on every PR                                    |
| State protection         | S3 versioned + encrypted, DynamoDB lock              |
| ECR immutability         | `image_tag_mutability = IMMUTABLE`                   |
| Image signing            | Not yet — see "What I'd add next"                    |

## Design Decisions

**Why Terraform over CDK?** Declarative state is easier to review; cleaner
`terraform plan` output for PR comments; standard in the gaming industry.

**Why Fargate over App Runner or Lambda?** Fargate is the boring correct answer
for a long-running HTTP service — no cold-start surprises, standard container
model, well-understood ops. App Runner would be faster to set up but is less
well-known. Lambda is over-indexed for a service that needs a healthcheck loop.

**Why public subnets instead of private + NAT?** Saves ~$32/mo/AZ. Acceptable
for a demo because the task SG only allows ingress from the ALB SG. For prod,
switch to private subnets with a NAT Gateway or VPC endpoints.

**Why tag-based naming (`bgs-hello-dev-*`) instead of Terraform workspaces for
multi-env?** Only one env in this repo today. When a second env lands, it'll
use a separate state file, not a workspace — workspace state drift is a
known footgun for long-lived envs.

**Why a `bootstrap` module at all?** The chicken-and-egg of "Terraform needs
state storage, state storage needs Terraform" is cleaner to solve with an
explicit local-state bootstrap than with magic scripts.

## Cost (rough, us-east-1, 1 task always on)

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

## What I'd Add Next

- [ ] HTTPS with ACM + Route53 record
- [ ] Cosign image signing + verification in deploy
- [ ] `dev` + `prod` environments with promotion
- [ ] Private subnets + NAT for prod
- [ ] Datadog / New Relic integration
- [ ] Blue/green via CodeDeploy
- [ ] Cost anomaly alarms
- [ ] Chaos testing (fault injection)
- [ ] Tighter GitHub Actions IAM (currently PowerUser — needs trimming)
