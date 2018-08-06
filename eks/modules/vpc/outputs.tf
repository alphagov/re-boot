output "vpc" {
  value = "${aws_vpc.managed.id}"
}

output "subnets" {
  value = "${aws_subnet.managed.*.id}"
}
