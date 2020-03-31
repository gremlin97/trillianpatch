#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
set -xe

yum update -y
yum install -y git mysql

# install golang
curl -o /tmp/go.tar.gz https://storage.googleapis.com/golang/go1.14.linux-amd64.tar.gz
tar -C /usr/local -xzf /tmp/go.tar.gz
export PATH=$PATH:/usr/local/go/bin

# This has to be done since the go get command is erroring out on missing packages
export BASE_DIR=/go/src/github.com/google/
export TRILLIAN_CHECKOUT=$BASE_DIR/trillian

mkdir -p $BASE_DIR
export GOPATH=/go
export GOROOT=/usr/local/go
export GOCACHE=$GOROOT/cache
mkdir -p $GOCACHE

cd $BASE_DIR
git clone https://github.com/google/trillian
cd $TRILLIAN_CHECKOUT
go build ./...
go get github.com/google/trillian/cmd/trillian_log_server

# Setup the DB
cd $TRILLIAN_CHECKOUT
export MYSQL_ROOT_USER=root
# The following 2 variables are set during the execution of the terraform
# script .
# See https://stackoverflow.com/questions/50835636/accessing-terraform-variables-within-user-data-provider-template-file
#export MYSQL_ROOT_PASSWORD=var.MYSQL_ROOT_PASSWORD
#export MYSQL_HOST=aws_rds_cluster.trillian-1.endpoint
export MYSQL_DATABASE=test
export MYSQL_USER=test
export MYSQL_PASSWORD=zaphod
export MYSQL_ROOT_PASSWORD=${PASSWORD_FROM_TF}
export MYSQL_HOST=${HOST_FROM_TF}
# To be obtained from wget 
#curl http://169.254.169.254/latest/meta-data/local-ipv4
# this is different from the other variables since doing this in terraform results in a Cycle error
export MYSQL_USER_HOST=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
export HOST=`curl http://169.254.169.254/latest/meta-data/public-hostname`
# This is a temporary patch so that the sql errors in the script are fixed. 
curl -o scripts/resetdb.sh https://raw.githubusercontent.com/hvram1/trillianpatch/master/resetdb.sh
./scripts/resetdb.sh --verbose --force

# Startup the Server
RPC_PORT=8090
HTTP_PORT=8091
/go/bin/trillian_log_server \
	--mysql_uri="$MYSQL_USER:$MYSQL_PASSWORD@tcp($MYSQL_HOST)/$MYSQL_DATABASE" \
	--rpc_endpoint="$HOST:$RPC_PORT" \
	--http_endpoint="$HOST:$HTTP_PORT" \
	--alsologtostderr
