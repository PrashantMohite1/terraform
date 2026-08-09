terraform {
  backend "s3" {
    bucket = "aws-us-east-bucket-1"
    key    = "terraform/aws/k8s-cluster.tfstate"
    region = "us-east-1"
  }
}
