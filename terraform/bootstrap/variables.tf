variable "aws_region" {
  description = "AWS region for bootstrap resources."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short project identifier used as a prefix."
  type        = string
  default     = "bgs-hello"
}

variable "github_repo" {
  description = "GitHub repo in 'org/repo' form that CI runs from."
  type        = string
}

variable "allowed_branches" {
  description = "Git refs allowed to assume the deploy role via OIDC."
  type        = list(string)
  default     = ["refs/heads/main"]
}
