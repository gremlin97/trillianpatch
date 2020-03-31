# This file should be in the examples/deployment/aws directory of the trillian checkout

# You can source the variables by doing a . init.sh 

#ssh-keygen -t rsa -N "" -b 2048 -C "trillian" -f trillian.pem

#chmod 400 trillian.pem

public_key_path=`pwd`/trillian.pem.pub

WHITELIST_CIDR="0.0.0.0/32"

MYSQL_ROOT_PASSWORD=test1947

USER_DATA_FILE=`pwd`/trillian-install.sh.tpl

key_name=trillian

#AWS_SECRET_ACCESS_KEY="XXXXXXXXXXXXXXXX"  # Replace with your key

#AWS_ACCESS_KEY="XXXXXXXXXXXXXXXXXXXXXX"   # Replace with your key
