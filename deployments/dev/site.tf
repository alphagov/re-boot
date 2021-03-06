variable "env" {}

variable "root_domain" {
  default = "govsvc.uk"
}

locals {
  domain_name = "${var.env}.${var.root_domain}"
}

data "aws_route53_zone" "root" {
  name         = "${var.root_domain}."
}

variable "region" {
  default = "eu-west-2"
}

variable "azs" {
  default = [
    "eu-west-2a",
    "eu-west-2b",
    "eu-west-2c",
  ]
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
  ]
}

terraform {
  backend "s3" {
    bucket = "gds-paas-k8s-shared-state"
    key    = "rafalp-network.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "${var.region}"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true

  tags {
    Name = "${var.env}"
  }
}

resource "aws_subnet" "subnets" {
  count = "${length(var.subnet_cidrs)}"

  vpc_id     = "${aws_vpc.vpc.id}"
  cidr_block = "${element(var.subnet_cidrs, count.index)}"

  availability_zone = "${element(
    var.azs,
    count.index
  )}"

  tags = "${map(
    "Name", "${var.env}-${count.index}",
    "SubnetType", "Public",
    "kubernetes.io/cluster/${var.env}", "shared",
    "kubernetes.io/role/elb", "1"
  )}"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "${var.env}"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags {
    Name = "${var.env}"
  }
}

resource "aws_route_table_association" "rta" {
  count = "${length(var.subnet_cidrs)}"

  subnet_id      = "${element(aws_subnet.subnets.*.id, count.index)}"
  route_table_id = "${aws_route_table.rt.id}"
}

resource "aws_route53_zone" "domain" {
  name = "${local.domain_name}"

  force_destroy = true
}

resource "aws_route53_record" "ns" {
  zone_id = "${data.aws_route53_zone.root.zone_id}"
  name    = "${local.domain_name}"
  type    = "NS"
  ttl     = "60"
  records = ["${aws_route53_zone.domain.name_servers}"]
}

output "vpc_id" {
  value = "${aws_vpc.vpc.id}"
}

output "subnet_ids" {
  value = "${join(",", aws_subnet.subnets.*.id)}"
}

output "azs" {
  value = "${join(",", var.azs)}"
}

output "domain_name" {
  value = "${aws_route53_zone.domain.name}"
}

output "domain_zone_id" {
  value = "${aws_route53_zone.domain.zone_id}"
}
