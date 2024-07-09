variable "deployment_name" {
  description = "Deployment Name"
  # No default
  # Use CLI or interactive input.
}

variable "aws_access_key" {
  description = "AWS Access Key"
  # No default
  # Use CLI or interactive input.
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  # No default
  # Use CLI or interactive input.
}

variable "aws_session_token" {
  description = "AWS Session Token"
  # No default
  # Use CLI or interactive input.
}

variable "regions" {
  default = ["us-east-1"]
}

variable "vpc_cidr" {
  default = ["10.1.0.0/16"]
}

variable "subnets" {
  default = [{
    us-east-1a = "10.1.1.0/24"
    us-east-1b = "10.1.2.0/24"
    us-east-1c = "10.1.3.0/24"
  }]
}

variable "ssh_public_key" {
  default = "~/.ssh/id_rsa.pub"
}

variable "ssh_user" {
  default = "ubuntu"
}

variable "volume_size" {
  default = 200
}

variable "volume_type" {
  default = "gp3"
}

// other optional edits *************************************
variable "cluster_size" {
  # Here we will create a 9-nodes cluster in one region
  default = [9]
}

// other possible edits *************************************
variable "crdb_release" {
  default = "https://binaries.cockroachdb.com/cockroach-v24.1.1.linux-amd64.tgz"
}

variable "machine_type" {
  default = "t2.2xlarge"
}

variable "machine_images" {
  // Ubuntu 24.04 LTS
  default = ["ami-04b70fa74e45c3917"]
}

variable "env" {
  default = ["us"]
}

//// Client Configuration

variable "client_vpc_cidr" {
  default = "172.71.0.0/16"
}

variable "client_region" {
  default = "us-west-2"
}

variable "client_subnet" {
  type = map
  default = {
    us-west-2a = "172.71.1.0/24"
  }
}

variable "client_machine_type" {
  default = "m6a.large"
}

variable "client_machine_image" {
  // Ubuntu 24.04 LTS
  default = "ami-0cf2b4e024cdb6960"
}

variable "demo_repository" {
  // Demo Github Repository
  default = "https://github.com/amine-crl/trade-app-crdb-multi-region.git"
}

variable "demo_schema_script" {
  default = "sql/trade.sql"
}

variable "database_name" {
  default = "trade_db"
}

variable "organization_name" {
  description = "Organization Name"
  # No default
  # Use CLI or interactive input.
}

variable "cluster_license" {
  description = "Cluster License"
  # No default
  # Use CLI or interactive input.
}

variable "backend_port" {
  default = 5000
}

variable "frontend_port" {
  default = 80
}