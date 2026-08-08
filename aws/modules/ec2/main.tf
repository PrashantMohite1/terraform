
resource aws_instance Server {
    ami = var.ami_id
    instance_type = var.instance_type

    tags = {
        Name = var.name
    }
}