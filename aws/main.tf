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

# -----------------
# ============================================================
# 1. IAM Role for K8s EC2 Instances (Master & Worker)
# ============================================================

resource "aws_iam_role" "k8s_node_role" {
  name = "k8s-node-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# ============================================================
# 2. Custom Policy for SSM Parameter Store Access
# ============================================================

resource "aws_iam_policy" "ssm_parameter_policy" {
  name        = "k8s-ssm-parameter-policy"
  description = "Allows K8s nodes to read/write join command token in Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "K8sSSMParameterAccess"
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/k8s/join-command"
      }
    ]
  })
}

# ============================================================
# 3. Attach Both Policies to the IAM Role
# ============================================================

# Attachment 1: AWS Managed SSM Core Policy (For Agent & Session Manager)
resource "aws_iam_role_policy_attachment" "ssm_managed_core" {
  role       = aws_iam_role.k8s_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attachment 2: Custom Parameter Store Policy (For K8s Token Exchange)
resource "aws_iam_role_policy_attachment" "ssm_parameter_access" {
  role       = aws_iam_role.k8s_node_role.name
  policy_arn = aws_iam_policy.ssm_parameter_policy.arn
}

# ============================================================
# 4. IAM Instance Profile (Bridge to EC2 Instances)
# ============================================================

resource "aws_iam_instance_profile" "k8s_instance_profile" {
  name = "k8s-node-instance-profile"
  role = aws_iam_role.k8s_node_role.name
}


#-------

module "server_1"{
    source = "./modules/ec2/"
    ami_id = data.aws_ami.ubuntu.id 
    instance_type = "t3.small"
    # instance_type = "t2.micro"
    ec2_name = "master"
    subnet_id = aws_subnet.private_sub_1.id
    private_ip = "10.0.4.11"
    vpc_security_group_ids = [aws_security_group.sg1.id, aws_security_group.calico_sg_1.id]
    associate_public_ip_address = false
    iam_instance_profile        = aws_iam_instance_profile.k8s_instance_profile.name
} 

module "server_2"{
    source = "./modules/ec2/"
    ami_id = data.aws_ami.ubuntu.id 
    instance_type = "t3.small"
    ec2_name = "worker-1"
    subnet_id = aws_subnet.private_sub_1.id
    private_ip = "10.0.4.12"
    vpc_security_group_ids = [aws_security_group.worker_sg1.id, aws_security_group.calico_sg_1.id ]
    associate_public_ip_address = false
    iam_instance_profile        = aws_iam_instance_profile.k8s_instance_profile.name
} 

module "server_3"{
    source = "./modules/ec2/"
    ami_id = data.aws_ami.ubuntu.id 
    instance_type = "t3.small"
    ec2_name = "worker-2"
    subnet_id = aws_subnet.private_sub_1.id
    private_ip = "10.0.4.13"
    vpc_security_group_ids = [aws_security_group.worker_sg1.id, aws_security_group.calico_sg_1.id ]
    associate_public_ip_address = false
    iam_instance_profile        = aws_iam_instance_profile.k8s_instance_profile.name
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
  availability_zone = "us-east-1a"
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
    "kubernetes.io/cluster/kubernetes" = "owned"
    
  }


  ingress {
    description = "Kubernetes API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  ingress {
    description = "Used by kube-apiserver, etcd"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  ingress {
    description = "kubelet API "
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  ingress {
    description = "kube-schedular"
    from_port   = 10259
    to_port     = 10259
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  ingress {
    description = "kube-control-manger"
    from_port   = 10257
    to_port     = 10257
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "worker_sg1" {
  vpc_id      = module.vpc_1.vpc_id

  tags = {
    Name = "${local.env}-sg-1"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }


  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  ingress {
    description = "kube-proxy"
    from_port   = 10256
    to_port     = 10256
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/20"]
  }

  ingress {
    description = "NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/20"]
  }
  


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########### security group for calico pods #######################################
resource "aws_security_group" "calico_sg_1" {
  vpc_id      = module.vpc_1.vpc_id

  tags = {
    Name = "${local.env}-calico-sg-1"
  }
}


# Calico BGP
resource "aws_vpc_security_group_ingress_rule" "calico_bgp" {
  security_group_id            = aws_security_group.calico_sg_1.id
  referenced_security_group_id = aws_security_group.calico_sg_1.id
  ip_protocol = "tcp"
  from_port   = 179
  to_port     = 179
  description = "Calico BGP between Kubernetes nodes"
}


# Calico IP-in-IP
resource "aws_vpc_security_group_ingress_rule" "calico_ipip" {
  security_group_id            = aws_security_group.calico_sg_1.id
  referenced_security_group_id = aws_security_group.calico_sg_1.id
  ip_protocol = "4"
  description = "Calico IP-in-IP between Kubernetes nodes"
}


# Allow all outbound
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.calico_sg_1.id
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
  description = "Allow all outbound traffic"
}


# ############## ssm parameter #####################################

resource "aws_ssm_parameter" "k8s_join_command" {
  name        = "/k8s/join-command"
  type        = "SecureString"
  value       = "PENDING"  # Placeholder value until Master boots
  description = "K8s cluster join command"

  # Prevents Terraform from reverting the token back to "PENDING" on future applies
  lifecycle {
    ignore_changes = [value]
  }
}


resource "aws_ssm_association" "run_script_for_master" {
  name = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.server_1.id]
  }

  parameters = {
    commands = join("\n", [
      "#!/bin/bash",
      "set -e",
      "# 1. Ensure git is installed",
      "if command -v git >/dev/null 2>&1; then echo 'git installed'; else sudo apt-get update && sudo apt-get install -y git; fi",
      "# 2. Clone repository into target folder",
      "sudo mkdir -p /k8s-setup",
      "sudo git clone https://github.com/PrashantMohite1/terraform.git /k8s-setup/terraform || (cd /k8s-setup/terraform && sudo git pull)",
      "# 3. Make script executable and run master setup",
      "sudo chmod +x /k8s-setup/terraform/scripts/k8s-cluster-setup.sh",
      "sudo /k8s-setup/terraform/scripts/k8s-cluster-setup.sh master 2>&1 | sudo tee /k8s-setup/k8s-setup.log"
    ])
  }

  depends_on = [
    aws_nat_gateway.nat_gw_1, aws_ssm_parameter.k8s_join_command
  ]

}


resource "aws_ssm_association" "run_script_for_workers" {
  name = "AWS-RunShellScript"

  targets {
    key    = "InstanceIds"
    values = [module.server_2.id, module.server_3.id]
  }

  parameters = {
    commands = join("\n", [
      "#!/bin/bash",
      "set -e",
      "# 1. Ensure git is installed",
      "if command -v git >/dev/null 2>&1; then echo 'git installed'; else sudo apt-get update && sudo apt-get install -y git; fi",
      "# 2. Clone repository into target folder",
      "sudo mkdir -p /k8s-setup",
      "sudo git clone https://github.com/PrashantMohite1/terraform.git /k8s-setup/terraform || (cd /k8s-setup/terraform && sudo git pull)",
      "# 3. Make script executable and run worker setup",
      "sudo chmod +x /k8s-setup/terraform/scripts/k8s-cluster-setup.sh",
      "sudo /k8s-setup/terraform/scripts/k8s-cluster-setup.sh worker 2>&1 | sudo tee /k8s-setup/k8s-setup.log"
    ])
  }

# Guarantees Terraform starts master SSM association creation before worker
  depends_on = [
    aws_ssm_association.run_script_for_master
  ]

}