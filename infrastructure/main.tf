terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 4.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "azs" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  ecr_repo_name     = "${var.project_name}-repo"
  ecs_cluster_name  = "${var.project_name}-cluster"
}
# Security Group pour l'ALB (front public)
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
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

# Security Group pour les instances EC2 / ECS
resource "aws_security_group" "ecs_sg" {
  name        = "${var.project_name}-ecs-sg"
  description = "Allow ALB to access ECS container instances"
  vpc_id      = var.vpc_id

  ingress {
    from_port                = var.container_port
    to_port                  = var.container_port
    protocol                 = "tcp"
    security_groups          = [aws_security_group.alb_sg.id]
    description              = "Allow HTTP from ALB SG"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB
resource "aws_lb" "app_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb_sg.id]
}

# Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "${var.project_name}-tg"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "instance"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-405"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Listener qui redirige le trafic vers le Target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ECR Repository
resource "aws_ecr_repository" "app_repo" {
  name = local.ecr_repo_name
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

# ECS Cluster
resource "aws_ecs_cluster" "ecs" {
  name = local.ecs_cluster_name
}

# IAM Role pour les instances EC2 dans le but de s'enregisrer dans ECS
resource "aws_iam_role" "ecs_instance_role" {
  name = "${local.ecs_cluster_name}-instance-role"
  assume_role_policy = data.aws_iam_policy_document.instance_assume.json
}

data "aws_iam_policy_document" "instance_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "instance_ecs" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${local.ecs_cluster_name}-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

# Launch Template for EC2 instances
resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "${local.ecs_cluster_name}-lt-"
  image_id      = var.ecs_ami_id
  instance_type = var.ec2_instance_type
  iam_instance_profile { name = aws_iam_instance_profile.ecs_instance_profile.name }
  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.ecs.name} >> /etc/ecs/ecs.config
EOF
    )
  vpc_security_group_ids = [aws_security_group.ecs_sg.id]
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ecs_asg" {
  name                      = "${local.ecs_cluster_name}-asg"
  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }
  min_size                 = var.ec2_asg_min_size
  max_size                 = var.ec2_asg_max_size
  desired_capacity         = var.ec2_asg_desired
  vpc_zone_identifier      = var.private_subnet_ids
  target_group_arns        = [aws_lb_target_group.app_tg.arn]
  #l’ASG s’appuie sur le Target Group / Load Balancer pour déterminer si l’instance est saine.
    health_check_type        = "ELB"  
  termination_policies     = ["OldestInstance"]
  tag {
    key                 = "Name"
    value               = "${local.ecs_cluster_name}-instance"
    propagate_at_launch = true
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_exec" {
  name = "${local.ecs_cluster_name}-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_attach" {
  role       = aws_iam_role.ecs_task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.project_name}-task"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn

  container_definitions = jsonencode([{
    name      = "app"
    image     = "${aws_ecr_repository.app_repo.repository_url}:${var.image_tag}"
    cpu       = var.task_cpu
    memory    = var.task_memory
    essential = true
    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
    }]
  }])
}

# ECS Service
resource "aws_ecs_service" "app_service" {
  name            = "${local.ecs_cluster_name}-service"
  cluster         = aws_ecs_cluster.ecs.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = var.desired_count
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  depends_on = [aws_autoscaling_group.ecs_asg]
}
