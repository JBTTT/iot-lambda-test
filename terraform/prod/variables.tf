variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Global name prefix for all resources"
  type        = string
  default     = "cet11-grp1"
}

variable "env" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

