variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.medium"
}

variable "ami_id" {
  description = "AMI ID for the Ubuntu instance"
  type        = string
  default     = "ami-04f59c565deeb2199"
}

variable "runner_token" {
  description = "GitHub Actions org-level runner token"
  type        = string
  sensitive   = true
}

variable "gh_pat" {
  description = "GitHub Personal Access Token for org runner registration"
  type        = string
  sensitive   = true
}
