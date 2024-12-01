terraform {
  required_version = ">= 0.13"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Specify the AWS provider and region
provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"  # Change as needed
}

variable "key_name" {
  description = "Name of the AWS SSH key pair"
}

variable "tmdb_api_key" {
  description = "Your TMDB API Key"
  type        = string
}

variable "dockerhub_username" {
  description = "Your Docker Hub username"
}

variable "dockerhub_password" {
  description = "Your Docker Hub password"
  type        = string
  sensitive   = true
}

variable "ingress_ports" {
  type        = list(number)
  description = "List of ingress ports to allow"
  default     = [80, 8080, 30007, 8081, 8082, 443, 9090, 3000, 9000, 9100]
}

# Data Sources
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "aws_vpc" "default" {
  default = true
}

# Security Group
resource "aws_security_group" "instance_sg" {
  name        = "instance_sg"
  description = "Security group for all instances"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Consider restricting to trusted IPs
  }

  dynamic "ingress" {
    for_each = var.ingress_ports
    content {
      description = "Ingress port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]  # Adjust as necessary
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "instance_sg"
  }
}

# IAM Role for EC2 Instances (Optional, if needed for AWS API access)
resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}

# Local variables for user_data scripts
locals {
  # Common Node Exporter installation script
  node_exporter_install = <<-EOF
    #!/bin/bash
    # Node Exporter Installation
    useradd --system --no-create-home --shell /bin/false node_exporter
    wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
    tar -xvf node_exporter-1.6.1.linux-amd64.tar.gz
    mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
    rm -rf node_exporter-1.6.1.linux-amd64*
    chown node_exporter:node_exporter /usr/local/bin/node_exporter

    cat <<EOT > /etc/systemd/system/node_exporter.service
    [Unit]
    Description=Node Exporter
    Wants=network-online.target
    After=network-online.target

    [Service]
    User=node_exporter
    Group=node_exporter
    Type=simple
    ExecStart=/usr/local/bin/node_exporter

    [Install]
    WantedBy=multi-user.target
    EOT

    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter
  EOF

  # Monitoring server installation script (Prometheus and Grafana)
  monitoring_user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update and install prerequisites
    apt-get update -y
    apt-get install -y wget curl gnupg2 software-properties-common apt-transport-https ca-certificates

    # Install Prometheus
    useradd --no-create-home --shell /bin/false prometheus
    mkdir /etc/prometheus /var/lib/prometheus
    chown prometheus:prometheus /etc/prometheus /var/lib/prometheus

    wget https://github.com/prometheus/prometheus/releases/download/v2.47.1/prometheus-2.47.1.linux-amd64.tar.gz
    tar -xvf prometheus-2.47.1.linux-amd64.tar.gz
    mv prometheus-2.47.1.linux-amd64/prometheus /usr/local/bin/
    mv prometheus-2.47.1.linux-amd64/promtool /usr/local/bin/
    mv prometheus-2.47.1.linux-amd64/consoles /etc/prometheus/
    mv prometheus-2.47.1.linux-amd64/console_libraries /etc/prometheus/
    rm -rf prometheus-2.47.1.linux-amd64*

    cat <<EOT > /etc/prometheus/prometheus.yml
    global:
      scrape_interval: 15s
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      - job_name: 'node_exporter'
        static_configs:
          - targets: ['localhost:9100']
      - job_name: 'jenkins'
        metrics_path: '/prometheus'
        static_configs:
          - targets: ['${aws_instance.mynode.private_ip}:8080']
    EOT

    chown -R prometheus:prometheus /etc/prometheus

    cat <<EOT > /etc/systemd/system/prometheus.service
    [Unit]
    Description=Prometheus
    Wants=network-online.target
    After=network-online.target

    [Service]
    User=prometheus
    Group=prometheus
    Type=simple
    ExecStart=/usr/local/bin/prometheus \\
      --config.file=/etc/prometheus/prometheus.yml \\
      --storage.tsdb.path=/var/lib/prometheus \\
      --web.console.templates=/etc/prometheus/consoles \\
      --web.console.libraries=/etc/prometheus/console_libraries \\
      --web.listen-address=0.0.0.0:9090 \\
      --web.enable-lifecycle

    [Install]
    WantedBy=multi-user.target
    EOT

    systemctl daemon-reload
    systemctl enable prometheus
    systemctl start prometheus

    # Install Grafana
    wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
    add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
    apt-get update -y
    apt-get install -y grafana

    systemctl enable grafana-server
    systemctl start grafana-server

    ${local.node_exporter_install}
  EOF

  # MyNode installation script (Jenkins, Docker, Trivy, SonarQube)
  mynode_user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update and install prerequisites
    apt-get update -y
    apt-get install -y openjdk-17-jdk wget curl gnupg2 apt-transport-https software-properties-common

    # Install Docker
    apt-get install -y docker.io
    usermod -aG docker ubuntu
    chmod 666 /var/run/docker.sock

    # Install Jenkins
    wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | apt-key add -
    sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
    apt-get update -y
    apt-get install -y jenkins
    systemctl enable jenkins
    systemctl start jenkins

    # Install Trivy
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee -a /etc/apt/sources.list.d/trivy.list
    apt-get update -y
    apt-get install -y trivy

    # Install SonarQube
    apt-get install -y unzip
    wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.1.69595.zip
    unzip sonarqube-9.9.1.69595.zip
    mv sonarqube-9.9.1.69595 /opt/sonarqube
    groupadd sonar
    useradd -d /opt/sonarqube -g sonar sonar
    chown -R sonar:sonar /opt/sonarqube

    cat <<EOT > /etc/systemd/system/sonar.service
    [Unit]
    Description=SonarQube service
    After=syslog.target network.target

    [Service]
    Type=forking
    ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
    ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
    User=sonar
    Group=sonar
    Restart=always
    LimitNOFILE=65536

    [Install]
    WantedBy=multi-user.target
    EOT

    sysctl -w vm.max_map_count=524288
    sysctl -w fs.file-max=131072
    echo 'fs.file-max = 131072' >> /etc/sysctl.conf
    echo 'vm.max_map_count = 524288' >> /etc/sysctl.conf
    ulimit -n 131072
    ulimit -u 8192

    systemctl daemon-reload
    systemctl enable sonar
    systemctl start sonar

    # Docker login to Docker Hub
    echo "${var.dockerhub_password}" | docker login -u "${var.dockerhub_username}" --password-stdin

    ${local.node_exporter_install}
  EOF

  # Master node user data script
  master_user_data = <<-EOF
    #!/bin/bash
    set -e

    # Set hostname
    hostnamectl set-hostname master

    # Update and install prerequisites
    apt-get update -y
    apt-get install -y docker.io
    usermod -aG docker ubuntu
    chmod 666 /var/run/docker.sock

    # Install Kubernetes components
    apt-get install -y apt-transport-https ca-certificates curl
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    apt-get update -y
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl

    # Initialize Kubernetes cluster
    kubeadm init --pod-network-cidr=10.244.0.0/16
    su - ubuntu -c "mkdir -p /home/ubuntu/.kube"
    cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    chown ubuntu:ubuntu /home/ubuntu/.kube/config

    # Install Flannel network plugin
    su - ubuntu -c "kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"

    ${local.node_exporter_install}
  EOF

  # Worker node user data script
  worker_user_data = <<-EOF
    #!/bin/bash
    set -e

    # Set hostname
    hostnamectl set-hostname worker

    # Update and install prerequisites
    apt-get update -y
    apt-get install -y docker.io
    usermod -aG docker ubuntu
    chmod 666 /var/run/docker.sock

    # Install Kubernetes components
    apt-get install -y apt-transport-https ca-certificates curl
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
    apt-get update -y
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl

    ${local.node_exporter_install}

    # Note: You will need to manually join the worker node to the cluster
  EOF
}

# EC2 Instances

# Monitoring Instance
resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  tags = {
    Name = "monitoring"
  }

  user_data = local.monitoring_user_data
}

# Master Node
resource "aws_instance" "master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.medium"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  tags = {
    Name = "master"
  }

  user_data = local.master_user_data
}

# Worker Nodes
resource "aws_instance" "worker_nodes" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  tags = {
    Name = "workerNode${count.index + 1}"
  }

  user_data = local.worker_user_data
}

# MyNode Instance
resource "aws_instance" "mynode" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.large"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  tags = {
    Name = "MyNode"
  }

  user_data = local.mynode_user_data
}

# Outputs
output "monitoring_public_ip" {
  value = aws_instance.monitoring.public_ip
}

output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "worker_nodes_public_ips" {
  value = [for instance in aws_instance.worker_nodes : instance.public_ip]
}

output "mynode_public_ip" {
  value = aws_instance.mynode.public_ip
}
