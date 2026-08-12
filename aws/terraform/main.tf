data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_vpc" "recovery" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}

resource "aws_internet_gateway" "recovery" {
  vpc_id = aws_vpc.recovery.id
  tags   = { Name = var.name }
}

resource "aws_subnet" "recovery" {
  vpc_id                  = aws_vpc.recovery.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = false
  tags                    = { Name = var.name }
}

resource "aws_route_table" "recovery" {
  vpc_id = aws_vpc.recovery.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.recovery.id
  }
  tags = { Name = var.name }
}

resource "aws_route_table_association" "recovery" {
  subnet_id      = aws_subnet.recovery.id
  route_table_id = aws_route_table.recovery.id
}

resource "aws_security_group" "recovery" {
  name        = var.name
  description = "Restricted reverse SSH ingress and SSM egress"
  vpc_id      = aws_vpc.recovery.id

  ingress {
    description = "NAS tunnel-only SSH principal"
    protocol    = "tcp"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    cidr_blocks = var.nas_source_cidrs
  }

  egress {
    description = "SSM and package HTTPS"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "VPC DNS UDP"
    protocol    = "udp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = ["${cidrhost(var.vpc_cidr, 2)}/32"]
  }

  egress {
    description = "VPC DNS TCP"
    protocol    = "tcp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = ["${cidrhost(var.vpc_cidr, 2)}/32"]
  }

  tags = { Name = var.name }
}

resource "aws_iam_role" "recovery" {
  name = "${var.name}-ssm"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.recovery.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "recovery" {
  name = "${var.name}-ssm"
  role = aws_iam_role.recovery.name
}

resource "aws_instance" "recovery" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.recovery.id
  vpc_security_group_ids      = [aws_security_group.recovery.id]
  iam_instance_profile        = aws_iam_instance_profile.recovery.name
  associate_public_ip_address = true
  source_dest_check           = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    encrypted   = true
    volume_size = 8
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    public_key   = trimspace(var.recovery_tunnel_public_key)
    reverse_port = var.reverse_port
  })

  tags = { Name = var.name }
}

resource "aws_eip" "recovery" {
  domain   = "vpc"
  instance = aws_instance.recovery.id
  tags     = { Name = var.name }
}
