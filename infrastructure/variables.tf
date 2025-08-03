variable "aws_region" {
  type    = string
  default = "eu-west-3"
}

variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ecs_ami_id" {
  type = string
}

variable "ec2_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "ec2_asg_min_size" {
  type    = number
  default = 1
}

variable "ec2_asg_max_size" {
  type    = number
  default = 2
}

variable "ec2_asg_desired" {
  type    = number
  default = 1
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "container_port" {
  type    = number
  default = 8000
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "image_tag" {
  type    = string
  default = "1.0.0"
}
