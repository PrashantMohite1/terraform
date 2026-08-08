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
}

module "vpc_1"{
    source = "./modules/vpc/"
    cidr_block = "10.0.0.0/24"
    env = local.env
}

resource "aws_subnet" "pub-sub-1" {
  vpc_id     = module.vpc_1.vpc_id
  cidr_block = "10.0.0.0/27"

  tags = {
    Name = "Public-subnet-1"
  }
}