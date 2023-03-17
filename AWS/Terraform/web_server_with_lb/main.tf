provider "aws" {
  region = "us-west-2"
}

locals {
  app_name = "my-webapp"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = local.app_name
  }
}

resource "aws_subnet" "public" {
  count = 2

  cidr_block = "10.0.${count.index + 1}.0/24"
  vpc_id     = aws_vpc.main.id

  tags = {
    Name = "${local.app_name}-public-${count.index}"
  }
}

resource "aws_security_group" "web" {
  name        = "${local.app_name}-web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["your-ip-address/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb" {
  name        = "${local.app_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

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

resource "aws_launch_configuration" "web" {
  name_prefix   = "${local.app_name}-web-lc"
  image_id      = "ami-xxxxxxx" # Replace with the desired Amazon Linux 2 AMI ID
  instance_type = "t2.micro"

  security_groups = [aws_security_group.web.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "Hello from ${local.app_name} instance $(curl http://169.254.169.254/latest/meta-data/instance-id)" > /var/www/html/index.html
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  name                 = "${local.app_name}-web-asg"
  launch_configuration = aws_launch_configuration.web.id
  min_size             = 2
  max_size             = 2
  desired_capacity     = 2

  vpc_zone_identifier = aws_subnet.public.*.id

  tag {
    key                 =
