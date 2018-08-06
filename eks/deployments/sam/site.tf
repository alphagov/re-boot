provider "aws" {
  region = "us-east-1"
	version = "~> 1.25"
}


terraform {
  backend "s3" {
    bucket = "gds-paas-k8s-shared-state"
    region = "us-east-1"
    key = "sam"
  }
}

module "vpc" {
  source = "../../modules/vpc"
  infrastructure_name = "sam"
}

module "kubernetes" {
  source = "../../modules/kubernetes"
  name = "sam"
  vpc = "${module.vpc.vpc}"
  subnets = "${module.vpc.subnets}"
}
