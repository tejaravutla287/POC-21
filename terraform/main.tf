terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_security_group" "pipeline_sg" {
  name        = "devsecops-single-node-sg"
  description = "Allow pipeline component traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # SSH Access
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Jenkins Dashboard
  }
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # SonarQube Dashboard
  }
  ingress {
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Target Web Application Port
  }
  ingress {
    from_port   = 32000
    to_port     = 32000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Grafana Dashboard
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "devsecops_host" {
  ami           = "ami-0e2c8caa4b6378d8c" # Ubuntu 24.04 LTS AMI in us-east-1. Change if using another region.
  instance_type = "c7i-flex.large"
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.pipeline_sg.id]

  root_block_device {
    volume_size           = 40
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # Critical Script: Creates an 8GB SWAP file to prevent crashes due to low RAM
  user_data = <<-EOF
              #!/bin/bash
              sudo fallocate -l 8G /swapfile
              sudo chmod 600 /swapfile
              sudo mkswap /swapfile
              sudo swapon /swapfile
              echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
              sudo sysctl vm.swappiness=10
              echo 'vm.swappiness=10' >> /etc/sysctl.conf
              EOF

  tags = {
    Name = "DevSecOps-POC-Host"
  }
}
