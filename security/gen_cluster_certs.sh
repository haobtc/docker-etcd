#!/bin/bash

DIR=`pwd`
CA_CONFIG="$DIR/ca-config.json"
CA_FILE="$DIR/cert/ca.pem"
CA_KEY_FILE="$DIR/cert/ca-key.pem"
CA_PROFILE="cluster"

function create_member() {
    local hosts
    while true; do
        printf "Enter to add hosts of member $1(leave it empty to end adding):"
        read host
        if [ -z "$host" ];then
            break
        fi
        if [ -z "$hosts" ]; then
            hosts=$host
        else
            hosts=$hosts","$host
        fi
        echo "Current hosts: $hosts"
    done
    json='{"CN":"'$1'","hosts":[""],"key":{"algo":"rsa","size":2048}}'
    cd "$DIR/certs"
    echo "$json" | cfssl gencert -ca=$CA_FILE -ca-key=$CA_KEY_FILE -config=$CA_CONFIG -profile=$CA_PROFILE -hostname="$hosts" - | cfssljson -bare $1
    cd $DIR
}

echo "== Start generating the cluster members' certificates =="
while true; do
    printf "Enter the member's name(leave it empty to end adding member):"
    read member
    if [ -z "$member" ];then
        echo "== All the members' certificates generating finished. $count members created. =="
        exit
    else
        count=$((count+1))
        create_member $member
        echo "Member($member)'s certificate successfully created. $count members already created."
    fi
done
