terraform {
  backend "s3" {
    encrypt = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  default_tags {
    tags = local.default_tags
  }
  region  = var.aws_region
  profile = var.profile
}

# Data sources
data "aws_caller_identity" "current" {}

data "aws_iam_role" "eventbridge_renew_exe_role" {
  name = "${var.prefix}-eventbridge-renew-execution-role"
}

data "aws_efs_access_point" "fsap_enable_renew" {
  access_point_id = var.fsap_id
}

data "aws_security_groups" "vpc_default_sg" {
  filter {
    name   = "group-name"
    values = ["default"]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.application_vpc.id]
  }
}

data "aws_subnet" "private_application_subnet" {
  for_each = toset(data.aws_subnets.private_application_subnets.ids)
  id       = each.value
}

data "aws_subnets" "private_application_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.application_vpc.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.prefix}-subnet-b", "${var.prefix}-subnet-c", "${var.prefix}-subnet-d"]
  }
}

data "aws_vpc" "application_vpc" {
  tags = {
    "Name" : "${var.prefix}"
  }
}

# Local variables
locals {
  account_id = data.aws_caller_identity.current.account_id
  default_tags = length(var.default_tags) == 0 ? {
    application : var.app_name,
    version : var.app_version
  } : var.default_tags
}