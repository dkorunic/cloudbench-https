output "instance public IPs" {
  value = "${aws_instance.test_node.*.public_ip}"
}
