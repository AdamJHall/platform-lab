module "nat" {
  for_each = aws_subnet.public

  source  = "RaJiska/fck-nat/aws"
  version = "~> 1.6"

  name                 = "${var.name}-nat-${each.key}"
  vpc_id               = aws_vpc.this.id
  subnet_id            = each.value.id
  use_cloudwatch_agent = true
  use_spot_instances   = var.nat_use_spot_instances
  instance_type        = var.nat_instance_type

  update_route_tables = true
  route_tables_ids = {
    "${var.name}-private-egress-rt-${each.key}" = aws_route_table.private_with_egress[each.key].id
  }

  tags = {
    Name        = "${var.name}-nat-${each.key}"
    Environment = var.environment
  }
}
