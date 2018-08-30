resource "aws_eip" "bosh" {
  vpc = true

  tags {
    Name = "${var.env}-bosh"
  }
}
