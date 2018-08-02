resource "aws_vpc" "managed" {
  cidr_block = "10.0.0.0/16"

  tags = "${
    map(
     "Name", "${var.infrastructure_name}-node",
     "kubernetes.io/cluster/${var.infrastructure_name}", "shared",
    )
  }"
}

resource "aws_subnet" "managed" {
  count = 2

  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block        = "10.0.${count.index}.0/24"
  vpc_id            = "${aws_vpc.managed.id}"

  tags = "${
    map(
     "Name", "${var.infrastructure_name}-node",
     "kubernetes.io/cluster/${var.infrastructure_name}", "shared",
    )
  }"
}

resource "aws_internet_gateway" "managed" {
  vpc_id = "${aws_vpc.managed.id}"

  tags {
    Name = "${var.infrastructure_name}"
  }
}

resource "aws_route_table" "managed" {
  vpc_id = "${aws_vpc.managed.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.managed.id}"
  }

  tags {
    Name = "${var.infrastructure_name}"
  }
}

resource "aws_route_table_association" "managed" {
  count = 2

  subnet_id      = "${aws_subnet.managed.*.id[count.index]}"
  route_table_id = "${aws_route_table.managed.id}"
}
