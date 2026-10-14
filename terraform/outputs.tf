output "vpc_id" {
  value = aws_vpc.main.id
}

output "availability_zones" {
  value = local.azs
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  value = aws_subnet.app[*].id
}

output "private_db_subnet_ids" {
  value = aws_subnet.db[*].id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.main.id
}
