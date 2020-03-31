set -vx

# This file should be in the examples/deployment/aws directory of the trillian checkout

# You can source the variables by doing a . init.sh 
rm -f trillian.pem trillian.pem.pub

ssh-keygen -t rsa -N "" -b 2048 -C "trillian" -f trillian.pem

chmod 400 trillian.pem

export TF_VAR_public_key_path=`pwd`/trillian.pem.pub

export TF_VAR_WHITELIST_CIDR="xx.xx.xxx.xxx/32"

export TF_VAR_MYSQL_ROOT_PASSWORD=test1947

export TF_VAR_USER_DATA_FILE=`pwd`/trillian-install.sh.tpl

export TF_VAR_key_name=trillian

export AWS_SECRET_ACCESS_KEY="XXXXXXXXXXXXXXXX"  # Replace with your key

export AWS_ACCESS_KEY="XXXXXXXXXXXXXXXXXXXXXX"   # Replace with your key
