resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = var.name
    Environment = var.environment
  }
}

resource "aws_default_security_group" "this" {
  vpc_id  = aws_vpc.this.id
  ingress = []
  egress  = []
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "${var.name}-igw"
    Environment = var.environment
  }
}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  public_subnet_map              = { for i, az in local.azs : az => var.subnet_cidrs.public[i] }
  private_subnet_map             = { for i, az in local.azs : az => var.subnet_cidrs.private[i] }
  private_with_egress_subnet_map = { for i, az in local.azs : az => var.subnet_cidrs.private_with_egress[i] }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnet_map

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = merge({
    Name        = "${var.name}-public-subnet-${each.key}"
    Environment = var.environment
    },
    var.subnet_tags.public
  )
}

resource "aws_subnet" "private_with_egress" {
  for_each = local.private_with_egress_subnet_map

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge({
    Name        = "${var.name}-private-egress-subnet-${each.key}"
    Environment = var.environment
    },
    var.subnet_tags.private_with_egress
  )
}

resource "aws_subnet" "private" {
  for_each = local.private_subnet_map

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge({
    Name        = "${var.name}-private-subnet-${each.key}"
    Environment = var.environment
    },
    var.subnet_tags.private
  )
}
