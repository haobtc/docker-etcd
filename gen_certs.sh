#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# STEP1: Install CloudFare's SSL utils
echo -e "${GREEN}Install CloudFare's SSL utils.${NC}"
if [[ -x "/usr/local/bin/cfssl" ]]; then
    echo "cfssl exists, skip downloading"
else
    echo "Downloading cfssl"
    curl -L https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 > /usr/local/bin/cfssl
    chmod +x /usr/local/bin/cfssl
fi

if [[ -x "/usr/local/bin/cfssljson" ]]; then
    echo "cfssljson exists, skip downloading"
else
    echo "Downloading cfssljson"
    curl -L https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 > /usr/local/bin/cfssljson
    chmod +x /usr/local/bin/cfssljson
fi


# STEP2: Input the node servers of the cluster, and their hostnames
echo -e "${GREEN}Input the node servers' name of the cluster, and their hostname.${NC}"
SERVERS=()
SERVERS_HOSTNAMES=()
function display_servers() {
    if [[ ! -z $SERVERS ]];then
        echo -e "${BLUE}${#SERVERS[@]} Server(s) added.${NC}"
        for i in "${!SERVERS[@]}"; do 
          printf "${BLUE}Server:%s\tHostnames:%s\n${NC}" "${SERVERS[$i]}" "${SERVERS_HOSTNAMES[$i]}"
        done
    fi
}

while true; do
    display_servers 
    echo "Enter the server name(leave empty to end):"
    read SERVER 
    if [ -z "$SERVER" ];then
        break
    fi
    while true; do
        printf "Add hostnames of $SERVER(leave empty to end):"
        read HOST
        if [ -z "$HOST" ];then
            break
        fi
        if [ -z "$HOSTS" ]; then
            HOSTS=$HOST
        else
            HOSTS=$HOSTS","$HOST
        fi
        echo "Server $SERVER contains hostnames: $HOSTS"
    done
    SERVERS+=($SERVER)
    SERVERS_HOSTNAMES+=($HOSTS)
    unset SERVER HOST HOSTS
done

display_servers
if [[ -z $SERVERS ]];then
  echo -e "${RED}No server added.${NC}"
  exit 1
fi

# STEP3: Generate CA
echo -e "${GREEN}Generate self signed CA.${NC}"
## Make the certificates directory
WORK_DIR=`pwd`
CERT_DIR="$WORK_DIR/cert"
CA_CONFIG="$CERT_DIR/ca-config.json"
CA_FILE="$CERT_DIR/ca.pem"
CA_KEY_FILE="$CERT_DIR/ca-key.pem"

if [[ ! -e $CERT_DIR ]]; then
    mkdir -p $CERT_DIR
elif [[ ! -d $CERT_DIR ]]; then
    echo "$CERT_DIR already exists but is not a directory" 1>&2
    exit 1
fi

## Generate CA
echo '{"CN":"CA","key":{"algo":"rsa","size":2048}}' | cfssl gencert -initca - | cfssljson -bare ca -
mv ca-key.pem $CERT_DIR
mv ca.csr $CERT_DIR
mv ca.pem $CERT_DIR

## Generate CA config for certificates
echo '{
"signing": {
   "default": {
       "expiry":"43800h"
   },
   "profiles": {
      "server": {
         "expiry": "43800h",
         "usages": [
             "signing",
             "key encipherment",
             "server auth"
         ]
      },
      "client": {
         "expiry": "43800h",
         "usages": [
             "signing",
             "key encipherment",
             "client auth"
         ]
      },
      "cluster": {
         "expiry": "43800h",
         "usages": [
             "signing",
             "key encipherment",
             "server auth",
             "client auth"
         ]
      }
    }
  }
}' > $CERT_DIR/ca-config.json

# STEP4: Generate servers' certificates
echo -e "${GREEN}Generate servers's certificates.${NC}"
cd $CERT_DIR
for i in "${!SERVERS_HOSTNAMES[@]}";do
    if [[ -z "$ALL_HOSTNAMES" ]];then
        ALL_HOSTNAMES=${SERVERS_HOSTNAMES[$i]}
    else
        ALL_HOSTNAMES=$ALL_HOSTNAMES","${SERVERS_HOSTNAMES[$i]}
    fi
done
echo -e "${BLUE}All the hostnames for server certificate: $ALL_HOSTNAMES${NC}"
echo '{"CN":"server","hosts":[""],"key":{"algo":"rsa","size":2048}}' | cfssl gencert -ca=$CA_FILE -ca-key=$CA_KEY_FILE -config=$CA_CONFIG -profile=server -hostname="$ALL_HOSTNAMES" - | cfssljson -bare server
cd $WORK_DIR

# STEP5: Generate clients' certificates
echo -e "${GREEN}Generating clients' certificates...${NC}"
cd "$CERT_DIR"
echo '{"CN":"client","hosts":[""],"key":{"algo":"rsa","size":2048}}'| cfssl gencert -ca=$CA_FILE -ca-key=$CA_KEY_FILE -config=$CA_CONFIG -profile=client - | cfssljson -bare client
cd $WORK_DIR

# STEP6: Generate cluster members' certificates 
echo -e "${GREEN}Generating cluster memebers' certificates...${NC}"
cd "$CERT_DIR"
for i in "${!SERVERS[@]}";do
    echo '{"CN":"'${SERVERS[$i]}'","hosts":[""],"key":{"algo":"rsa","size":2048}}'| cfssl gencert -ca=$CA_FILE -ca-key=$CA_KEY_FILE -config=$CA_CONFIG -profile=cluster -hostname=${SERVERS_HOSTNAMES[$i]} - | cfssljson -bare ${SERVERS[$i]}
done
cd $WORK_DIR
