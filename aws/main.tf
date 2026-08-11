locals {
  region = "us-east-1"
  env = "dev"
}

provider "aws"{
    region = local.region
}


data aws_ami "ubuntu" {
    
    most_recent = true 

    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    }

    owners = ["099720109477"] # Canonical
}


module "server-1"{
    source = "./modules/ec2/"
    ami_id = data.aws_ami.ubuntu.id 
    instance_type = "t2.micro"
    ec2_name = "master"
    subnet_id = aws_subnet.pub-sub-1.id
    vpc_security_group_ids = [aws_security_group.sg1.id]
    associate_public_ip_address = true

}

# module "server-2"{
#     source = "./modules/ec2/"
#     ami_id = data.aws_ami.ubuntu.id 
#     instance_type = "t4g.small"
#     ec2_name = "worker-node-1"
#     subnet_id = aws_subnet.pub-sub-1.id
#     vpc_security_group_ids = [aws_security_group.sg1.id]
#     associate_public_ip_address = true

# }

module "vpc_1"{
    source = "./modules/vpc/"
    cidr_block = "10.0.0.0/24"
    env = local.env
    vpc_name = "${local.env}-vpc"
    
}

resource "aws_subnet" "pub-sub-1" {
  vpc_id     = module.vpc_1.vpc_id
  cidr_block = "10.0.0.0/27"

  tags = {
    Name = "${local.env}-pub-subnet"
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = module.vpc_1.vpc_id

  tags = {
    Name = "${local.env}-igw"
  }
}


resource "aws_route_table" "rt1" {
  vpc_id = module.vpc_1.vpc_id

  # since this is exactly the route AWS will create, the route will be adopted
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

tags = {
  Name = "${local.env}-route-table-1"
}

}


resource "aws_route_table_association" "rt1_association" {
  subnet_id      = aws_subnet.pub-sub-1.id
  route_table_id = aws_route_table.rt1.id
}


resource "aws_security_group" "sg1" {
  vpc_id      = module.vpc_1.vpc_id

  tags = {
    Name = "${local.env}-sg-1"
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


