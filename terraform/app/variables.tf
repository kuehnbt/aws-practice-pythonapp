variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "bgs-hello"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "image_uri" {
  description = "Full ECR image URI including the git SHA tag. Passed from CI."
  type        = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "log_retention_days" {
  type    = number
  default = 14
}
