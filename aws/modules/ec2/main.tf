
resource aws_instance "ec2" {
    ami = var.ami_id
    instance_type = var.instance_type
    vpc_security_group_ids = var.vpc_security_group_ids
    subnet_id = var.subnet_id
    iam_instance_profile = var.iam_instance_profile
    tags = {
        Name = var.ec2_name
    }
    associate_public_ip_address = var.associate_public_ip_address
    metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforces IMDSv2
    http_put_response_hop_limit = 2          # Allows the agent to fetch credentials
  }
}


output id {
  value       = aws_instance.ec2.id
}
