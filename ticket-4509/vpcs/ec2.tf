# SSH Key Pair
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content  = tls_private_key.example.private_key_pem
  filename = "${path.module}/my-ec2-key.pem"
}

resource "aws_key_pair" "generated_key" {
  key_name   = "my-ec2-key"
  public_key = tls_private_key.example.public_key_openssh
}

# Data blocks to fetch existing resources
data "aws_subnet_ids" "eks_subnets" {
  vpc_id = module.vpc.vpc_id # Reference the VPC ID from the module output
}

# Security group for EC2 instances
resource "aws_security_group" "ec2_access" {
  name        = "ec2-access"
  description = "Allow SSH and EKS cluster communication"
  vpc_id      = module.vpc.vpc_id # Reference the VPC ID from the module output

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs # Use the variable containing the allowed CIDRs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instances
resource "aws_instance" "eks_admin_nodes" {
  count         = var.instance_count
  ami           = var.amazon_linux_2_ami
  instance_type = var.ec2_instance_type
  subnet_id     = element(data.aws_subnet_ids.eks_subnets.ids, count.index % length(data.aws_subnet_ids.eks_subnets.ids))
  key_name      = aws_key_pair.generated_key.key_name
  security_groups = [
    aws_security_group.ec2_access.name,
  ]

  tags = {
    Name = "eks-admin-node-${count.index + 1}"
  }

  depends_on = [module.vpc] 
}

