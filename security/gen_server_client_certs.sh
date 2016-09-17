#!/bin/bash

DIR=`pwd`
CA_CONFIG="$DIR/ca-config.json"
CA_FILE="$DIR/cert/ca.pem"
CA_KEY_FILE="$DIR/cert/ca-key.pem"

function create_server() {
    local hosts
    while true; do
        printf "Enter to add hosts of the server(leave empty to end adding):"
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
    json='{"CN":"server","hosts":[""],"key":{"algo":"rsa","size":2048}}'
    cd "$DIR/certs"
    echo "$json" | cfssl gencert -ca=$CA_FILE -ca-key=$CA_KEY_FILE -config=$CA_CONFIG -profile=server -hostname="$hosts" - | cfssljson -bare server
    cd $DIR
}

function create_client() {
    json='{"CN":"client","hosts":[""],"key":{"algo":"rsa","size":2048}}'
    cd "$DIR/certs"
    echo "$json" | cfssl gencert -ca=$CA_FILE -ca-key=$CA_KEY_FILE -config=$CA_CONFIG -profile=client - | cfssljson -bare client
    cd $DIR
}

echo "== Start generating the server's certificates =="
create_server
echo "== The server's certificate generating finished =="

echo "== Start generating the client's certificates =="
create_client
echo "== The client's certificate generating finished =="
