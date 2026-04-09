# Partial backend configuration.
#
# Terraform evaluates this block BEFORE variables are loaded, so it cannot
# reference var.* or locals. Instead we declare the backend type here and pass
# the actual bucket/table/region at `init` time via -backend-config flags.
#
# In CI the values come from GitHub Actions secrets:
#     terraform init \
#       -backend-config="bucket=${TF_STATE_BUCKET}" \
#       -backend-config="key=bgs-hello/app/terraform.tfstate" \
#       -backend-config="region=${AWS_REGION}" \
#       -backend-config="dynamodb_table=${TF_LOCK_TABLE}" \
#       -backend-config="encrypt=true"
#
# Locally, use a partial-config file (see backend.dev.hcl.example):
#     cp backend.dev.hcl.example backend.dev.hcl   # then edit
#     terraform init -backend-config=backend.dev.hcl
terraform {
  backend "s3" {}
}
