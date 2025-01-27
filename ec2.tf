resource "aws_ec2_managed_prefix_list" "vpn_admins_ips" {
  name           = "${local.name_prefix}-admins-ip"
  address_family = "IPv4"
  max_entries    = 10

  entry {
    cidr        = "0.0.0.0/0"
    description = "Everyone Temporary For Few Days"
  }

  tags = {
    Name = "${local.name_prefix}-admins-ip"
  }
}

resource "aws_security_group" "vpn_box" {
  name        = local.name_prefix
  description = "Security group for VPN EC2 instance"

  ingress {
    from_port   = var.vpn_udp_port
    to_port     = var.vpn_udp_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"] # not sure where to lock
  }

  ingress {
    description = "wireguard port"
    from_port   = var.vpn_wg_port
    to_port     = var.vpn_wg_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [aws_ec2_managed_prefix_list.vpn_admins_ips.id]
  }
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [aws_ec2_managed_prefix_list.vpn_admins_ips.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # assuming need to access intenet while using vpn
  }

  tags = {
    Name = local.name_prefix
  }
  vpc_id = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "ec2" {
  name = local.name_prefix
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
  inline_policy {
    name   = "${local.name_prefix}-policy"
    policy = data.aws_iam_policy_document.inline_policy.json
  }
}

resource "aws_iam_instance_profile" "ec2" {
  name = local.name_prefix
  role = aws_iam_role.ec2.name
}

# enter into instance via ssm
resource "aws_iam_role_policy_attachment" "policy-AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.ec2.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_instance" "vpn" {
  ami                         = var.ami_id
  associate_public_ip_address = true
  instance_type               = var.instance_type
  iam_instance_profile        = aws_iam_instance_profile.ec2.id
  subnet_id                   = data.aws_subnets.public.ids[0]
  tags = {
    Name = local.name_prefix
  }
  user_data = base64encode(local.vpn_user_data)
  volume_tags = {
    Name = local.name_prefix
  }
  vpc_security_group_ids = [aws_security_group.vpn_box.id]
  depends_on = [
    aws_efs_mount_target.efs
  ]
}

#allocate eip
resource "aws_eip" "eip" {
  domain   = "vpc"
  instance = aws_instance.vpn.id
  tags = {
    Name = local.name_prefix
  }
}
