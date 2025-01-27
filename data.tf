data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    Name = "*private*"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    Name = "*public*"
  }
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_iam_policy_document" "inline_policy" {
  statement {
    actions = ["elasticfilesystem:DescribeMountTargets"]
    resources = [
      "arn:aws:elasticfilesystem:${local.aws.region}:${local.aws.account_id}:file-system/${aws_efs_file_system.efs.id}",
      "arn:aws:elasticfilesystem:${local.aws.region}:${local.aws.account_id}:access-point/${aws_efs_access_point.access_point.id}",
    ]
  }
  statement {
    actions   = ["ec2:DescribeAvailabilityZones"]
    resources = ["*"]
  }
}

# data "template_file" "userdata_script" {
#   template = file("${path.module}/userdata.sh.tpl")
#   vars = {
#     name_prefix  = local.name_prefix
#     efs_id       = aws_efs_file_system.efs.id
#     access_point = aws_efs_access_point.access_point.id
#   }
# }

data "aws_ami" "ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-*"]
  }
}

