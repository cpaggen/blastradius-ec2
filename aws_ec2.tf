provider "aws" {
  region = "eu-central-1"
  # credentials come from ~/.aws/credentials (AWS CLI)
}

resource "aws_vpc" "terraformvpc1" {
  cidr_block       = "10.10.0.0/16"
  instance_tenancy = "dedicated"

  tags = {
    Name = "blastradius"
  }
}

resource "aws_subnet" "first" {
  cidr_block        = "10.10.1.0/24"
  vpc_id            = aws_vpc.terraformvpc1.id
  availability_zone = "eu-central-1a"
}

resource "aws_route_table" "mgmt-rt" {
  vpc_id = aws_vpc.terraformvpc1.id
  tags = {
    Name = "cpaggen-rt"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.terraformvpc1.id

  tags = {
    Name = "cpaggen-internet"
  }
}

resource "aws_route" "mgmt-default" {
  route_table_id         = aws_route_table.mgmt-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
  depends_on = [
    aws_route_table.mgmt-rt,
    aws_internet_gateway.igw
  ]
}

resource "aws_main_route_table_association" "main-rt" {
  vpc_id         = aws_vpc.terraformvpc1.id
  route_table_id = aws_route_table.mgmt-rt.id
}

locals {
  rulesmap = {
    "HTTP" = {
      port        = 80,
      cidr_blocks = ["0.0.0.0/0"],
    }
    "SSH" = {
      port        = 22,
      cidr_blocks = ["0.0.0.0/0"],
    },
    "BLASTR" = {
      port        = 8888,
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

resource "aws_security_group" "cpaggen-sg" {
  vpc_id = aws_subnet.first.vpc_id

  dynamic "ingress" {
    for_each = local.rulesmap
    content {
      description = ingress.key # HTTP or SSH
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cpaggen-default"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "ec2_instance_one" {
  associate_public_ip_address = true
  ami                         = "ami-02584c1c9d05efa69" // Ubuntu 20.04LTS - not using data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  key_name                    = "frankfurt-keypair-one"
  vpc_security_group_ids      = [aws_security_group.cpaggen-sg.id]
  subnet_id                   = aws_subnet.first.id
  user_data                   = <<EOF
#!/bin/bash
echo "Setting up blast-radius dependencies" > /home/ubuntu/user_data.txt
sudo hostname "blastradius"
sudo curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-add-repository universe
sudo apt-get update -y
sudo apt-get install terraform python3.9 net-tools graphviz -y
pip3 install --upgrade pip
pip3 install blastradius graphviz
pip3 install -U jinja2
mkdir -p /home/ubuntu/.aws
curl -o /home/ubuntu/aws.tf https://github.com/cpaggen/blastradius-ec2/blob/dev/aws.rename
touch /home/ubuntu/semaphore.txt
echo "done with dependencies" >> /home/ubuntu/user_data.txt
EOF

  connection {
    agent       = false
    host        = self.public_ip
    private_key = file("frankfurt-keypair-one.pem")
    type        = "ssh"
    user        = "ubuntu"
  }

  provisioner "file" {
    source      = "/home/cisco/.aws/config"
    destination = "/home/ubuntu/aws-config"
  }
  provisioner "file" {
    source      = "/home/cisco/.aws/credentials"
    destination = "/home/ubuntu/aws-credentials"
  }

  // TF has no way to wait for cloudinit (user_data) to complete
  // I therefore rely on a simple file-as-a-semaphore hack in the
  // inline script section below
  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /home/ubuntu/semaphore.txt ]; do sleep 2; done",
      "mv /home/ubuntu/aws-config /home/ubuntu/.aws/config",
      "mv /home/ubuntu/aws-credentials /home/ubuntu/.aws/credentials",
      "terraform init",
      "terraform plan -out=plan.out",
      "terraform apply -auto-approve",
      "blast-radius --serve /home/ubuntu --port 8888 &"
    ]
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Name        = "blastradius"
  }
}

output "vpc-id" {
  value = aws_vpc.terraformvpc1.id
}

output "ec1-public-ip" {
  value = aws_instance.ec2_instance_one.public_ip
}
