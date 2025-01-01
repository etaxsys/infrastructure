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

resource "aws_network_interface" "eks_admin_eni" {
  count         = var.ec2_instance_count
  subnet_id     = element(module.subnets.public_subnet_ids, count.index % length(module.subnets.public_subnet_ids))
  security_groups = [aws_security_group.ec2_access.id]

  tags = {
    Name = "eks-admin-eni-${count.index + 1}"
  }
}

# EC2 instances
resource "aws_instance" "eks_admin_nodes" {
  count         = var.ec2_instance_count
  ami           = var.generic_linux_ami_id
  instance_type = var.ec2_instance_type
#   subnet_id = element(module.subnets.public_subnet_ids, count.index % length(module.subnets.public_subnet_ids))
  key_name      = aws_key_pair.generated_key.key_name
#   security_groups = [
#     aws_security_group.ec2_access.name,
#   ]
  network_interface {
    device_index          = 0
    network_interface_id  = aws_network_interface.eks_admin_eni[count.index].id
  }

  tags = {
    Name = "eks-admin-node-${count.index + 1}"
  }
  user_data = <<-EOF
    #!/bin/bash

    # Update the instance
    sudo apt update -y
    sudo apt upgrade -y

    # Install necessary tools
    sudo apt install -y git python3 python3-pip unzip apt-transport-https ca-certificates curl software-properties-common net-tools

    # Install boto3 (AWS SDK for Python)
    pip3 install boto3

    # Install the latest AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install

    # Install Docker
    sudo apt remove -y docker docker-engine docker.io containerd runc
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker

    # Add the ubuntu user to the Docker group to allow running docker commands without sudo
    sudo usermod -aG docker ubuntu

    # Cleanup
    rm -rf awscliv2.zip aws

    # Install Terraform
    curl -O https://releases.hashicorp.com/terraform/1.9.5/terraform_1.9.5_linux_arm64.zip && \
    unzip terraform_1.9.5_linux_arm64.zip && \
    sudo mv terraform /usr/local/bin/ && \
    unset TF_LOG_PATH && \
    export TF_LOG=ERROR && \
    rm -rf terraform_1.9.5_linux_arm64.zip

    # Set up kubectl
    ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        PLATFORM="amd64"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        PLATFORM="arm64"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/$PLATFORM/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

    # Create SSH key directory and set permissions
    mkdir -p /home/ubuntu/.ssh
    chmod 700 /home/ubuntu/.ssh

    # Add your private key (replace with your actual private key contents)
    cat << 'KEY' > /home/ubuntu/.ssh/id_agenerette_ec2_instances
    -----BEGIN OPENSSH PRIVATE KEY-----
    <your-private-key-contents-here>
    -----END OPENSSH PRIVATE KEY-----
    KEY

    chmod 600 /home/ubuntu/.ssh/id_agenerette_ec2_instances

    # Configure SSH to use the correct key for GitHub
    cat << 'CONFIG' > /home/ubuntu/.ssh/config
    Host github.com
        HostName github.com
        User git
        IdentityFile /home/ubuntu/.ssh/id_agenerette_ec2_instances
    CONFIG

    chmod 600 /home/ubuntu/.ssh/config

    # Set the correct ownership for the SSH directory and files
    chown -R ubuntu:ubuntu /home/ubuntu/.ssh

    # Test SSH connection to GitHub (optional for debugging... it won't work, initially)
    # su - ubuntu -c "ssh -T git@github.com"
  EOF

  depends_on = [module.vpc, module.subnets] 
}

