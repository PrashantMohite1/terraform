variable ami_id {
  type        = string
  default     = ""
  description = "add AMI Id of required os"
}


variable instance_type {
    type = string 
    description = "specify instance type"
}

variable ec2_name {
  type        = string
  default     = ""
  description = "description"
}


variable vpc_security_group_ids{
  type = list(string)
}


variable subnet_id {
  type        = string

}


variable associate_public_ip_address {
  type        = bool
  default     = true
}

