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

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
 
  tags = {
    Name    = "vpc-migrate-${var.yourname}"
    project = "azure-migrate-lab"
  }
}
 
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
 
  tags = {
    Name = "igw-migrate-${var.yourname}"
  }
}
 
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
 
  tags = {
    Name = "snet-migrate-${var.yourname}"
  }
}
 
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
 
  tags = {
    Name = "rt-migrate-${var.yourname}"
  }
}
 
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

resource "aws_security_group" "source_vm" {
  name        = "sg-migrate-source-${var.yourname}"
  description = "Allow HTTPS and RDP for Azure Migrate lab"
  vpc_id      = aws_vpc.main.id
 
  ingress {
    description = "HTTPS for Azure Migrate appliance communication"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  ingress {
    description = "RDP for admin access"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
 ingress {
    description = "WinRM for discovery / remote management"
    from_port   = 5985
    to_port     = 5985
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  ingress {
    description = "SMB for Mobility service push / SMB transfer"
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow ASR replication traffic"
    from_port   = 9443
    to_port     = 9443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  tags = {
    Name = "sg-migrate-source-${var.yourname}"
  }
}

resource "aws_instance" "source_vm" {
  ami                    = var.windows_ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.source_vm.id]
   
  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = false
  }
  
   user_data = <<-EOF
    <powershell>
    net user Administrator "${var.admin_password}"
    winrm quickconfig -force
    winrm set winrm/config/service/auth @{Basic="true"}
    winrm set winrm/config/service @{AllowUnencrypted="true"}
    </powershell>
  EOF
 
  volume_tags = {
    Name    = "vol-migrate-source-${var.yourname}"
    project = "azure-migrate-lab"
  }
 
  tags = {
    Name    = "ec2-migrate-source-${var.yourname}"
    project = "azure-migrate-lab"
  }
}
