variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "bgs-hello"
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
