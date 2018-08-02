variable "name" {}
variable "vpc" {}
variable "subnets" { type = "list" }

data "aws_region" "current" {}
data "aws_availability_zones" "available" {}
