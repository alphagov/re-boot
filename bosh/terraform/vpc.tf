resource "aws_vpc" "bosh" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags {
    Name = "${var.env}-bosh"
  }
}

resource "aws_subnet" "public" {
  count             = "${var.zone_count}"
  vpc_id            = "${aws_vpc.bosh.id}"
  cidr_block        = "${lookup(var.infra_cidrs, format("zone%d", count.index))}"
  availability_zone = "${lookup(var.zones, format("zone%d", count.index))}"

  tags {
    Name = "${var.env}-public-${lookup(var.zones, format("zone%d", count.index))}"
  }
}
