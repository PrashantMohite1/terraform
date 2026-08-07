

provider "aws"{
    region = "us-east-1"
}


data aws_ami "ubuntu" {
    
    most_recent = true 

    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }

    # owners = [099720109477]
    owners = ["099720109477"] # Canonical
}


resource aws_instance ec1 {
    ami = data.aws_ami.ubuntu.id
    instance_type = "t2.micro"
}