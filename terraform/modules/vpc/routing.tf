resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name        = "${var.name}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_with_egress" {
  for_each = local.private_with_egress_subnet_map

  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "${var.name}-private-egress-rt-${each.key}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_with_egress" {
  for_each = aws_subnet.private_with_egress

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_with_egress[each.key].id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name        = "${var.name}-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
