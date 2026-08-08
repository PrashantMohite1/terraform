
resource aws_vpc "vpc" {
    cidr_block = var.cidr_block
    tags = {
        Createdby = "terraform" 
        Env = var.env
    }
}


output vpc_id {
  value       = aws_vpc.vpc.id
}
