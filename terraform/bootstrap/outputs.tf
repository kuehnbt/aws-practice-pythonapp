output "tf_state_bucket" {
  description = "Copy into terraform/app/backend.tf"
  value       = aws_s3_bucket.tf_state.id
}

output "tf_lock_table" {
  description = "Copy into terraform/app/backend.tf"
  value       = aws_dynamodb_table.tf_lock.name
}

output "gha_role_arn" {
  description = "Paste into GitHub Actions secret AWS_ROLE_ARN"
  value       = aws_iam_role.gha_deploy.arn
}

output "ecr_repo_url" {
  description = "Paste into GitHub Actions workflow env"
  value       = aws_ecr_repository.app.repository_url
}
