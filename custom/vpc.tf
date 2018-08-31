module "vpc" {
  source = "github.com/scholzj/terraform-aws-vpc"

  aws_region = "eu-west-2"
  aws_zones = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  vpc_name = "rafalp"
  vpc_cidr = "10.0.0.0/16"
  private_subnets = "true"

  tags = {
    Name = "rafalp"
  }
}
