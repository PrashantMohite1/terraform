
resource aws_instance Server {
    ami = var.ami_id
    instance_type = var.instance_type
    vpc_security_group_ids = var.vpc_security_group_ids
    subnet_id = var.subnet_id
    tags = {
        Name = var.ec2_name
    }
}