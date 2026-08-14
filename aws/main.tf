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

# 1. Create the IAM Role that allows EC2 to assume it
resource "aws_iam_role" "ssm_role" {
  name = "${local.env}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" } 
      }
    ]
  })
}

# 2. Attach the official AWS SSM Policy to the role
resource "aws_iam_role_policy_attachment" "ssm_policy_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${local.env}-ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

module "server_1"{
    source = "./modules/ec2/"
    ami_id = data.aws_ami.ubuntu.id 
    instance_type = "t2.micro"
    ec2_name = "master"
    subnet_id = aws_subnet.private_sub_1.id
    vpc_security_group_ids = [aws_security_group.sg1.id]
    associate_public_ip_address = false
    iam_instance_profile        = aws_iam_instance_profile.ssm_instance_profile.name
} 

module "vpc_1"{
    source = "./modules/vpc/"
    cidr_block = "10.0.0.0/20"
    env = local.env
    vpc_name = "${local.env}-vpc"
    
}

resource "aws_subnet" "public_sub_1" {
  vpc_id     = module.vpc_1.vpc_id
  cidr_block = "10.0.0.0/22"

  tags = {
    Name = "${local.env}-public-subnet"
  }
}

resource "aws_subnet" "private_sub_1" {
  vpc_id     = module.vpc_1.vpc_id
  cidr_block = "10.0.4.0/22"
  tags = {
    Name = "${local.env}-private-subnet"
  }
}


######## Internet Gateway ###########################
resource "aws_internet_gateway" "internet_gw_1" {
  vpc_id = module.vpc_1.vpc_id

  tags = {
    Name = "${local.env}-igw"
  }
}


####### NAT Gateway #################
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw_1" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_sub_1.id

  tags = {
    Name = "${local.env}-nat-gw-1"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.internet_gw_1]
}



# resource "aws_nat_gateway_eip_association" "eip_association_1" {
#   allocation_id  = aws_eip.nat_eip.id
#   nat_gateway_id = aws_nat_gateway.nat_gw_1.id
# }

# public route table

resource "aws_route_table" "public_rt1" {
  vpc_id = module.vpc_1.vpc_id

  # since this is exactly the route AWS will create, the route will be adopted
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gw_1.id
  }

tags = {
  Name = "${local.env}-route-table-1"
}

}

# private route table

resource "aws_route_table" "private_rt1" {
  vpc_id = module.vpc_1.vpc_id

  # since this is exactly the route AWS will create, the route will be adopted
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gw_1.id
  }

tags = {
  Name = "${local.env}-route-table-1"
}

}


resource "aws_route_table_association" "public_rt1_association" {
  subnet_id      = aws_subnet.public_sub_1.id
  route_table_id = aws_route_table.public_rt1.id
}

resource "aws_route_table_association" "private_rt1_association" {
  subnet_id      = aws_subnet.private_sub_1.id
  route_table_id = aws_route_table.private_rt1.id
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



resource "aws_ssm_association" "run_script" {
  name = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.server_1.id]
  }

  parameters = {
    commands = "echo 'Terraform triggered this via SSM!' > /tmp/ssm_output.txt"
  }
}

