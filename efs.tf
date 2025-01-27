# security group for efs
resource "aws_security_group" "efs_sg" {
  name        = "${local.name_prefix}-efs"
  description = "SG for ${local.config.environment}-vpn EFS volume"
  vpc_id      = var.vpc_id

  ingress {
    description     = "TLS from VPC"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.vpn_box.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
  tags = {
    Name = local.name_prefix
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "random_pet" "server" {}

resource "aws_efs_file_system" "efs" {
  # Nasty nasty nasty
  creation_token = "${random_pet.server.id}-vpn"
  tags = {
    Name = local.name_prefix
  }
  encrypted = true
}

resource "aws_efs_mount_target" "efs" {
  for_each        = toset(data.aws_subnets.private.ids)
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_backup_policy" "policy" {
  file_system_id = aws_efs_file_system.efs.id

  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_access_point" "access_point" {
  file_system_id = aws_efs_file_system.efs.id
  # posix_user {
  #   gid            = "1000"
  #   uid            = "1000"
  #   secondary_gids = ["755"]
  # }
  #
  root_directory {
    path = "/"
  }
  tags = {
    Name = local.name_prefix
  }
}

