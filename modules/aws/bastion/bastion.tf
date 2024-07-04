terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

############################################################
# Network Interface

resource "aws_network_interface" "nic" {
  subnet_id       = var.subnet
  security_groups = var.security_groups

  tags = merge("${var.resource_tags}",{
    Name = "${var.name}-client-nic"
  })
}


# Elastic IP to the Network Interface
resource "aws_eip" "eip" {
  network_interface         = aws_network_interface.nic.id
  associate_with_private_ip = aws_network_interface.nic.private_ip
  depends_on                = [aws_instance.bastion]

  tags = merge("${var.resource_tags}",{
    Name = "${var.name}-client-eip"
  })
}


############################################################
# EC2

resource "aws_instance" "bastion" {
  ami               = var.machine_image 
  instance_type     = var.machine_type
  availability_zone = var.availability_zone
  key_name          = var.ssh_key_name
  depends_on        = [var.dependencies]

  tags = merge("${var.resource_tags}",{
    Name = "${var.name}-client"
  })

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.nic.id
  }

  user_data = <<-EOF
  #!/bin/bash
  echo "$(date) - PREPARING client" >> /home/${var.ssh_user}/prepare_client.log
  apt-get -y update
  apt-get -y install vim
  apt-get -y install iotop
  apt-get -y install iputils-ping

  apt-get install -y netcat
  apt-get install -y dnsutils
  export DEBIAN_FRONTEND=noninteractive
  export TZ="UTC"
  apt-get install -y tzdata
  ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime
  dpkg-reconfigure --frontend noninteractive tzdata

  mkdir /home/${var.ssh_user}/install
  cd /home/${var.ssh_user}/install
  apt-get -y install build-essential autoconf automake libpcre3-dev libevent-dev pkg-config zlib1g-dev libssl-dev

  binaries="${var.cockroach_release}"
  filename=$${binaries##*/}
  packagename=$${filename%.*}
  mkdir /home/${var.ssh_user}/install
  echo "$(date) - PREPARE done" >> /home/${var.ssh_user}/prepare_client.log

  ################
  echo "$(date) - DOWNLOADING CockroachDB from : " ${var.cockroach_release} >> /home/${var.ssh_user}/prepare_client.log
  wget "${var.cockroach_release}" -P /home/${var.ssh_user}/install
  sudo tar xvf /home/${var.ssh_user}/install/$filename -C /home/${var.ssh_user}/install/

  echo "$(date) - INSTALLING CockroachDB" >> /home/${var.ssh_user}/prepare_client.log
  cd /home/${var.ssh_user}/install
  sudo cp -i $packagename/cockroach /usr/local/bin/
  sudo mkdir -p /usr/local/lib/cockroach
  sudo cp -i $packagename/lib/libgeos.so /usr/local/lib/cockroach/
  sudo cp -i $packagename/lib/libgeos_c.so /usr/local/lib/cockroach/

  sleep 10
  echo "$(date) - INSTALL done" >> /home/${var.ssh_user}/prepare_client.log

  ################
  # Install Docker
  echo "$(date) - Installing Docker" >> /home/${var.ssh_user}/prepare_client.log
  sudo apt update >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo apt -y install apt-transport-https ca-certificates curl software-properties-common >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo apt -y install docker-ce >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo groupadd docker
  sudo usermod -aG docker ${var.ssh_user}
  sudo systemctl restart docker
  sudo chmod 666 /var/run/docker.sock

  ###############
  # Install Docker Compose
  echo "$(date) - Installing Docker Compose" >> /home/${var.ssh_user}/prepare_client.log
  sudo apt update >> /home/${var.ssh_user}/prepare_client.log 2>&1
  sudo apt -y install docker-compose >> /home/${var.ssh_user}/prepare_client.log 2>&1

  ################
  # Clone the demo repository
  echo "$(date) - Clone the demo repository ${var.demo_repository}" >> /home/${var.ssh_user}/create_demo.log

  repository="${var.demo_repository}"
  cd /home/${var.ssh_user}
  command="git clone $repository"
  echo "$command" >> /home/${var.ssh_user}/create_demo.log
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/create_demo.log

  ################
  # Check CRDB Cluster DNS
  echo "$(date) - Check CRDB Cluster DNS" >> /home/${var.ssh_user}/create_demo.log

  status_code=$(curl --write-out '%%{http_code}' --silent  --output /dev/null "http://${var.cluster_fqdn}:8080")
  while [ "$status_code" != "200" ]; do
      echo "Retry in 20 seconds..." >> /home/${var.ssh_user}/create_demo.log
      sleep 20
      status_code=$(curl --write-out '%%{http_code}' --silent  --output /dev/null "http://${var.cluster_fqdn}:8080")
  done

  echo "$(date) - CRDB Cluster is Up." >> /home/${var.ssh_user}/create_demo.log

  ################
  # Create Database Schema
  name=$${repository##*/}
  foldername=$${name%.*}
  cd /home/${var.ssh_user}/$foldername

  echo "$(date) - Configure Cluster's License" >> /home/${var.ssh_user}/create_demo.log
  command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"SET CLUSTER SETTING cluster.organization = '${var.cluster_organization}'\""
  echo "$command" >> /home/${var.ssh_user}/create_demo.log
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/create_demo.log
  command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"SET CLUSTER SETTING enterprise.license = '${var.cluster_license}';\""
  echo "$command" >> /home/${var.ssh_user}/create_demo.log
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/create_demo.log

  echo "$(date) - Create ${var.database_name} Schema" >> /home/${var.ssh_user}/create_demo.log
  command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --file ${var.demo_schema_script}"
  echo "$command" >> /home/${var.ssh_user}/create_demo.log
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/create_demo.log

  echo "$(date) - Associate Regions for ${var.database_name}" >> /home/${var.ssh_user}/create_demo.log
  command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"ALTER DATABASE ${var.database_name} SET PRIMARY REGION '${var.regions[0]}';\""
  echo "$command" >> /home/${var.ssh_user}/create_demo.log
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/create_demo.log
  command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"ALTER DATABASE ${var.database_name} ADD REGION '${var.regions[1]}';\""
  echo "$command" >> /home/${var.ssh_user}/create_demo.log
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/create_demo.log
  command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"ALTER DATABASE ${var.database_name} ADD REGION '${var.regions[2]}';\""
  echo "$command" >> /home/${var.ssh_user}/create_demo.log
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/create_demo.log

  echo "$(date) - Create SURVIVE REGION FAILURE for ${var.database_name}" >> /home/${var.ssh_user}/create_demo.log
  command="cockroach sql --url postgresql://root@${var.cluster_fqdn}:26257 --insecure --execute=\"ALTER DATABASE ${var.database_name} SURVIVE REGION FAILURE;\""
  echo "$command" >> /home/${var.ssh_user}/create_demo.log
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/create_demo.log

  ################
  # Prepare Demo
  echo "$(date) - Prepare docker compose file" >> /home/${var.ssh_user}/create_demo.log

  echo "
  services:
    # React.js frontend service
    frontend:
      build: ./frontend
      ports:
        - \"${var.frontend_port}:80\"

    # Node.js backend service
    backend:
      build: ./backend
      ports:
        - \"${var.backend_port}:5000\"
  "  | sudo tee docker-compose.yml

  sleep 10

  ################
  # Prepare backend
  echo "$(date) - Prepare backend config file" >> /home/${var.ssh_user}/create_demo.log

  echo "{
    \"db\": {
      \"connection_strings\": [\"postgresql://root@${var.cluster_fqdn}:26257/${var.database_name}?sslmode=disable\"]
    }
  }" | sudo tee backend/config/default.json

  sleep 10

  ################
  # Start backend
  echo "$(date) - Start Demo Backend" >> /home/${var.ssh_user}/start_demo.log
  command="sudo docker compose up -d backend"
  echo "$command" >> /home/${var.ssh_user}/create_demo.log
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/start_demo.log

  ################
  # Prepare frontend
  echo "$(date) - Prepare frontend config file" >> /home/${var.ssh_user}/create_demo.log
  node_external_addr=`curl ifconfig.me/ip`

  echo "{
    \"server\": {
      \"host\" : \"$node_external_addr\",
      \"port\": ${var.backend_port}
    }
  }" | sudo tee frontend/src/config.json

  sleep 10

  ################
  # Start frontend
  echo "$(date) - Start Demo Frontend" >> /home/${var.ssh_user}/start_demo.log
  command="sudo docker compose up -d frontend"
  echo "$command" >> /home/${var.ssh_user}/create_demo.log
  sudo bash -c "$command 2>&1" >> /home/${var.ssh_user}/start_demo.log

  echo "$(date) - DONE creating client" >> /home/${var.ssh_user}/prepare_client.log
  EOF

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    delete_on_termination = true
  }
}
