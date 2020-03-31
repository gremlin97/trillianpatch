## Steps to be followed ##
### Install terraform ###

<code>
$ cd /tmp

$ export VER="0.12.24"
$ wget https://releases.hashicorp.com/terraform/${VER}/terraform_${VER}_linux_amd64.zip

$ unzip terraform_0.12.24_linux_amd64.zip

$ sudo mv terraform /usr/local/bin

$ terraform init
</code>

The above steps installs terraform and the aws providers .  To check you should see the following

<code>
$ terraform version
</code>
<pre>
Terraform v0.12.24
+ provider.aws v2.54.0
</pre>

## Install golang ##

The following version of "Go" works . **I tried 14.1 and I got errors in tooling. (29/3/2020) **
<code>
$ curl -o /tmp/go.tar.gz https://storage.googleapis.com/golang/go1.14.linux-amd64.tar.gz

$ tar -C /usr/local -xzf /tmp/go.tar.gz
$ export PATH=$PATH:/usr/local/go/bin
</code>

Verify that the variables GOPATH and GOROOT are set correctly

<code>
$ set | grep GO
</code>
<pre>
GOPATH=/home/wipro/go:/home/wipro/projects/goprojects
GOROOT=/usr/local/go
</pre>

<code>
$ go version
</code>

<pre>
go version go1.14.1 linux/amd64
</pre>
## Checkout the trillian source code and build ##

Check out the project in the $GOPATH path. (In this case /home/wipro/go is in the $GOPATH) . Go is very particular on the location of the source files . 
You can skip the last build step if you are developing on AWS since the terraform code sets up a EC2 instance with the same steps. 


<code>

$ mkdir -p /home/wipro/go/src/github.com/google/
$ cd /home/wipro/go/src/github.com/google
$ git clone https://github.com/google/trillian
$ cd trillian
$ go build ./...
</code>

This should build the trillian log_server and the trillian_mapserver

## Setting up the Terraform AWS deployment 

<code>
$ cd /home/wipro/go/src/github.com/google/trillian/examples/deployment/aws

</code>

## Setting up a key pair 
<code>
$ ssh-keygen -t rsa -N "" -b 2048 -C "trillian"
</code>

<pre>
Generating public/private rsa key pair.
Enter file in which to save the key (/home/wipro/.ssh/id_rsa): trillian.pem
Your identification has been saved in trillian.pem.
Your public key has been saved in trillian.pem.pub.
The key fingerprint is:
SHA256:lPSSlJ1LhCt8AU0B/CPb2ZB/0PeDEGMFRDi749Nwkcc trillian
The key's randomart image is:
+---[RSA 2048]----+
|     .o==*==o.   |
|      .o=*++     |
|     . .===o=    |
|      +.Boo+.E.  |
|       *S*..+... |
|      . o+o... ..|
|        . =.    .|
|         o .     |
|          .      |
+----[SHA256]-----+

</pre>

The above step will generate two files trillian.pem and trillian.pub in the current directory. Change the permission of the private key . If you don't change the permissions then you cannot use this key and you will get a permission error. 

<code>
$ chmod 400 trillian.pem
</code>

## Setting up the variables ##

The name of the public key file ( the full path). Without the full path you will get an invalid /non-ssh key error while importing. 
The name of the key 
<code>
$ export TF_VAR_public_key_path=`pwd`/trillian.pub

$ export TF_VAR_key_name="trillian"
</code>

Set up the variables for MYSQL ROOT User password. Replace XXXX with your own password 
<code>
$ export TF_VAR_MYSQL_ROOT_PASSWORD="XXXXXXX"
</code>

Find your IP and enable white listing of the IP. The /32 is important since this is a CIDR format. 

<code>
$ export TF_VAR_WHITELIST_CIDR="117.219.250.204/32"
</code>

Export your AWS credentials
<code>
$ export AWS_ACCESS_KEY="XXXXXXXXXXXXXXXXXXXXXX"
$ export AWS_SECRET_ACCESS_KEY="XXXXXXXXXXXXXXXXXXXX"
</code>

## Plan and Apply ##
This will create a file called TerraformPlan
<code>
$ terraform plan -out TerraformPlan 2>&1 | tee TerraformPlanMessages

$ terraform apply "TerraformPlan" 2>&1 | tee TerraformApplyMessages

</code>
If you would like to re run the above steps you need to do the following 

## Importing to Terraform ##
Import  into terraform so that you don't get the  already exists error 
<code>
$ terraform import aws_rds_cluster_parameter_group.trillian trillian-pg

$ terraform import aws_key_pair.auth trillian
</code>

## Logging and debugging ##

<code>
$ terraform show 
</code>
Will list out the resources created. You can get the name of the EC2 instance and log into the EC2 instance using following command

<code>
$ ssh -i "trillian.pem" ec2-user@ec2-xx-xxx-xxx-xx.us-west-2.compute.amazonaws.com
</code>

The logs of the user-data script is located at 
<code>
$ sudo su
$ cd /var/log
$ tail -f user-data.log
</code>

## Known Issues ##
The apply command fails the first time with the following errors. If you re run the plan and the run the apply command again it works.
<pre>
Error: Error creating DB Subnet Group: DBSubnetGroupDoesNotCoverEnoughAZs: DB Subnet Group doesn't meet availability zone coverage requirement. Please add subnets to cover at least 2 availability zones. Current coverage: 1
	status code: 400, request id: 614f7d43-5378-413c-b7b0-ba56102d074e

  on terraform.tf line 87, in resource "aws_db_subnet_group" "dbsubnet":
  87: resource "aws_db_subnet_group" "dbsubnet" {


</pre>

<pre>
Error: no matching subnet found for vpc with id vpc-0ccdbf64aac782a44

  on terraform.tf line 82, in data "aws_subnet_ids" "created":
  82: data "aws_subnet_ids" "created" {


</pre>