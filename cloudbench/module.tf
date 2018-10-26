provider "aws" {
  region = "${var.region}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_key_pair" "key" {
  key_name   = "cloudbench-test-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC3/60QJkdFf/yFz0/9E1C0UpnksLPCoRO9/8okwCtIX8kTXNYqh1esr83/Pu4e8TVX+3ZHErN/aMdQJLuNYQdmSwqfPJiqg7/VmkCPaHATb1AH9CK/R3XwLPWsC/Tl8d9lmiM4L3Npq4Zp8ovew3hrFUXy8IkdpklWEnF/0YoNzBpFlnBOg/l0o2tpEZM2jBHDwZf3TXva6ynlNxVH+n59QPinzqbDF0zBJysEKfpNHauCLyrRZm0wcmLAbV9UhBUDOupI3ReS3ejzT8bGJlv4rw3nbEnJTVpBYe8XZ00vJbbilP46AoIZ6lAomMD5MgVGy0ZrDsEPL6aCZ3KZHbPx dkorunic@Dinkos-Mac-mini.local"
}

data "aws_ami" "ubuntu_aws_amis" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

resource "aws_vpc" "vpc" {
  cidr_block           = "20.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags {
    Name = "cloudbench-${var.region}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags = {
    Name = "cloudbench-${var.region}-igw"
  }
}

resource "aws_subnet" "subnet" {
  count                   = "${length(data.aws_availability_zones.available.names)}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index)}"
  map_public_ip_on_launch = true
  availability_zone       = "${element(data.aws_availability_zones.available.names, count.index)}"

  tags = {
    Name = "cloudbench-${element(data.aws_availability_zones.available.names, count.index)}-public"
  }
}

resource "aws_route_table" "route" {
  count  = "${length(data.aws_availability_zones.available.names)}"
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
}

resource "aws_route_table_association" "a" {
  count          = "${length(data.aws_availability_zones.available.names)}"
  subnet_id      = "${element(aws_subnet.subnet.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.route.*.id, count.index)}"
}

// Security group for test LB nodes
resource "aws_security_group" "test_node_sg" {
  name        = "test_node_sg"
  description = "Instance test SG: pass SSH, HTTP, HTTPS and Dashboard traffic by default"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    from_port   = 3
    to_port     = 4
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }
}

resource "aws_instance" "test_node" {
  count                  = "${length(data.aws_availability_zones.available.names) * var.servers_per_az}"
  instance_type          = "${var.test_instance_type}"
  ami                    = "${data.aws_ami.ubuntu_aws_amis.id}"
  subnet_id              = "${element(aws_subnet.subnet.*.id, count.index)}"
  key_name               = "${aws_key_pair.key.key_name}"
  vpc_security_group_ids = ["${aws_security_group.test_node_sg.id}"]

  user_data = <<EOF
  #cloud-config
  runcmd:
    - systemctl stop apt-daily.service
    - systemctl kill --kill-who=all apt-daily.service
    - systemctl stop apt-daily.timer
  EOF

  tags {
    Name = "cloudbench_test_node"
  }
}
