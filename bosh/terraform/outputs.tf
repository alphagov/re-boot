output "subnet_id" {
  value = ["${aws_subnet.public.*.id}"]
}

output "availability_zone" {
  value = ["${aws_subnet.public.*.availability_zone}"]
}

output "eip_address" {
  value = "${aws_eip.bosh.public_ip}"
}
