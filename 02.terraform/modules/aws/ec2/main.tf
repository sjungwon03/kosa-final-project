data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "ssm" {
  count = var.create_ssm_role ? 1 : 0

  name = "${var.name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.create_ssm_role ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ssm[0].name
}

resource "aws_iam_instance_profile" "ssm" {
  count = var.create_ssm_role ? 1 : 0

  name = "${var.name}-ssm-profile"
  role = aws_iam_role.ssm[0].name

  tags = var.tags
}

resource "aws_instance" "this" {
  count = length(var.subnet_ids)

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index]
  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = var.key_name
  iam_instance_profile   = var.create_ssm_role ? aws_iam_instance_profile.ssm[0].name : null

  user_data = var.user_data

  tags = merge(var.tags, {
    Name = "${var.name}-${count.index + 1}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Security group for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    description = "HAProxy HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HAProxy HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HAProxy Stats"
    from_port   = 8404
    to_port     = 8404
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "ICMP from VPN"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.onprem_cidr]
  }

  ingress {
    description = "ICMP from Public"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-sg"
  })
}