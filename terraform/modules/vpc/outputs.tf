output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, keyed by AZ name"
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "private_subnet_ids" {
  description = "IDs of the isolated private subnets (no egress), keyed by AZ name"
  value       = { for az, subnet in aws_subnet.private : az => subnet.id }
}

output "private_with_egress_subnet_ids" {
  description = "IDs of the private subnets with NAT egress, keyed by AZ name"
  value       = { for az, subnet in aws_subnet.private_with_egress : az => subnet.id }
}
