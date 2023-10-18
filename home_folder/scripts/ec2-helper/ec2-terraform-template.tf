terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region              = "$REGION"
  allowed_account_ids = [$ACCOUNT]
}

locals {
  base_name = "$NAME"
}

# KMS key for connecting to the server
resource "tls_private_key" "server_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key_file" {
  content  = tls_private_key.server_private_key.private_key_pem
  filename = "${path.module}/${local.base_name}_server_key.pem"
}

resource "local_file" "public_key_file" {
  content  = tls_private_key.server_private_key.public_key_openssh
  filename = "${path.module}/${local.base_name}_server_key_pub.pem"
}

resource "aws_key_pair" "server_key_pair" {
  key_name   = "${local.base_name}-server-key-pair"
  public_key = tls_private_key.server_private_key.public_key_openssh
}

resource "aws_security_group" "allow_ssh_security_group" {
  name        = "${local.base_name}-allow-ssh"
  description = "Allow SSH inbound traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_all_outbound_traffic_security_group" {
  name        = "${local.base_name}-allow-all-outbound-traffic"
  description = "Allow all outbound traffic"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "server" {
  ami           = "$AMI"
  instance_type = "$INSTANCE_TYPE"
  key_name      = aws_key_pair.server_key_pair.key_name
  vpc_security_group_ids = [
    aws_security_group.allow_ssh_security_group.id,
    aws_security_group.allow_all_outbound_traffic_security_group.id,
  ]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 256
    delete_on_termination = true
    tags = {
      Name = "${local.base_name}-server-volume"
    }
  }

  user_data = file("${path.module}/ec2-terraform-template-user-data.sh")

  tags = {
    Name = "${local.base_name}-server"
  }
}

# Output to allow for easy SSH-ing into the server
output "server_ip" {
  value       = aws_instance.server.public_ip
}

output "server_key" {
  value       = local_file.private_key_file.filename
}

output "server_public_key" {
  value       = local_file.public_key_file.filename
}