resource "aws_security_group" "bosh" {
  name        = "bosh"
  description = "BOSH deployed VMs"
  vpc_id      = "${aws_vpc.bosh.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${compact(concat(var.admin_cidrs, list(var.concourse_egress_cidr)))}"]
  }

  ingress {
    from_port   = 6868
    to_port     = 6868
    protocol    = "tcp"
    cidr_blocks = ["${compact(concat(var.admin_cidrs, list(var.concourse_egress_cidr)))}"]
  }

  ingress {
    from_port   = 25555
    to_port     = 25555
    protocol    = "tcp"
    cidr_blocks = ["${compact(concat(var.admin_cidrs, list(var.concourse_egress_cidr)))}"]
  }

  tags {
    Name = "${var.env}-bosh"
  }
}
