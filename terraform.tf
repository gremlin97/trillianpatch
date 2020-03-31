# This file should be in the examples/deployment/aws directory of the trillian checkout
variable "WHITELIST_CIDR" {
  description="Your IP block to whitelist access from"
}
variable "MYSQL_ROOT_PASSWORD" { }
variable "key_name"   { } 
variable "public_key_path" { }
variable "USER_DATA_FILE" { }
variable "base_cidr" {
  description = "cidr for vpc" #this variable is utilized in the locals.tf
  type = string
  default = "10.0.0.0/16"
}
# This code is from https://github.com/terraform-providers/terraform-provider-aws/issues/3223
#
variable "max_subnets" {
  description = "Maximum number of subnets which can be created for CIDR blocks calculation. Default to length of names argument"
  default = "6"
}

variable "netnum_private_db" {
  type = string
  default = "2"
}

variable "amount_private_db_subnets" {
  type = string
  default = "3"
}

variable "tags" {
  type = map
  description = "optional tags"

  default = {
    Name = "trillian"

    vpc = "test_vpc"
    env = "nonprd"
    project = "Triilian on AWS"
  }
}


# Specify the provider and access details
provider "aws" {
  region     = "us-west-2"
  version = "~> 2.54"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "test_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

resource "aws_subnet" "instance_subnet" {

  cidr_block = "10.0.10.0/24"
  vpc_id = aws_vpc.test_vpc.id
  availability_zone = data.aws_availability_zones.main.names[1]
  map_public_ip_on_launch = false

  tags = {
    Name = "Instance-subnet"
  }
}

resource "aws_subnet" "db_subnet_prv" {
  count = var.amount_private_db_subnets
  #cidr_block = "${cidrsubnet(var.base_cidr, ceil(log(var.max_subnets, 2)), (var.netnum_private_db + count.index))}"
  cidr_block = cidrsubnet(var.base_cidr, 4, (var.netnum_private_db + count.index))
  vpc_id = aws_vpc.test_vpc.id
  availability_zone = data.aws_availability_zones.main.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.tags["Name"]}-db-prv-${count.index}-subnet"
  }
}
# From the terraform documentation https://www.terraform.io/docs/providers/aws/d/subnet_ids.html
data "aws_subnet_ids" "created" {
  vpc_id = aws_vpc.test_vpc.id
  
}


resource "aws_db_subnet_group" "dbsubnet" {
  name = "userdb_subnet_group_1"
  description = "user db subnet group 1"
  #subnet_ids = ["${aws_subnet.db_subnet_prv.*.id}"]
  subnet_ids = data.aws_subnet_ids.created.ids
}

/*
availability zones data template
*/
data "aws_availability_zones" "main" {}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "gw1" {
  vpc_id = aws_vpc.test_vpc.id
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.test_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw1.id
}

# Security group for the RDS database
resource "aws_security_group" "trillian-database" {
  name        = "trillian-database-security-group"
  description = "security group for database"
  vpc_id = aws_vpc.test_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.WHITELIST_CIDR,aws_subnet.instance_subnet.cidr_block]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.trillian-instance.id]
  }

}


# Security group to access
# the instances over SSH REST HTTP
resource "aws_security_group" "trillian-instance" {
  name        = "trillian-instance-security-group"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.test_vpc.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.WHITELIST_CIDR]
  }

  ingress {
    from_port   = 8090
    to_port     = 8091
    protocol    = "tcp"
    cidr_blocks = [var.WHITELIST_CIDR]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.WHITELIST_CIDR]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_file" "trillian-install" {
  template = file(var.USER_DATA_FILE)

  vars = {
     HOST_FROM_TF= aws_rds_cluster_instance.cluster_instances-1[0].endpoint
     PASSWORD_FROM_TF=var.MYSQL_ROOT_PASSWORD
     
  }
}
resource "aws_key_pair" "auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}
/* The Instance */

/* select the latest official hvm amazon linux release */
data "aws_ami" "trillian" {
  most_recent      = true
  executable_users = ["all"]

  name_regex = "^amzn-ami-hvm"
  owners     = ["amazon"]
}

resource "aws_instance" "trillian" {
  ami                         = data.aws_ami.trillian.id
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.trillian-instance.id]
  subnet_id = aws_subnet.instance_subnet.id
  availability_zone = data.aws_availability_zones.main.names[1]
  associate_public_ip_address = true
  # The name of our SSH keypair we created above.
  key_name                    = aws_key_pair.auth.id
  # vpc_id                      = aws_vpc.test_vpc.id
  tags = {
    Name = "trillian"
  }

  user_data =  data.template_file.trillian-install.rendered


}
#####

/* The Database */

resource "aws_rds_cluster" "trillian-1" {
  cluster_identifier      = "trillian-1"
  database_name           = "test"
  master_username         = "root"
  master_password         = var.MYSQL_ROOT_PASSWORD
  skip_final_snapshot     = true
  port                    = 3306
  vpc_security_group_ids  = [aws_security_group.trillian-database.id]
  availability_zones      = ["us-west-2a", "us-west-2b", "us-west-2c"]
  storage_encrypted       = true
  apply_immediately       = true
  db_subnet_group_name    = aws_db_subnet_group.dbsubnet.id

}

resource "aws_rds_cluster_instance" "cluster_instances-1" {
  count               = 1
  identifier          = "trillian-1-${count.index}"
  cluster_identifier  = aws_rds_cluster.trillian-1.id
  instance_class      = "db.r3.large"
  publicly_accessible = true
  apply_immediately   = true
}


resource "aws_rds_cluster_parameter_group" "trillian" {
  name        = "trillian-pg"
  family      = "aurora5.6"

  # Whether InnoDB returns errors rather than warnings for exceptional conditions.
  # replaces: `sql_mode = STRICT_ALL_TABLES`
  parameter {
    name  = "innodb_strict_mode"
    value = "0"
  }
}




