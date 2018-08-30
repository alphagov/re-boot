resource "aws_key_pair" "bosh" {
  key_name   = "${var.env}-bosh-key"
  public_key = "${var.public_key}"
}
