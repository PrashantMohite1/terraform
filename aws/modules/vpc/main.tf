
resource aws_vpc "vpc" {
    cidr_block = var.cidr_block
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags = {
        Createdby = "terraform" 
        Env = var.env
        Name = var.vpc_name 
    }
}


output vpc_id {
  value       = aws_vpc.vpc.id
}


