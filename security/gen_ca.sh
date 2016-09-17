#!/bin/bash

CA_DIR='cert'

if [[ ! -e $CA_DIR ]]; then
    mkdir -p $CA_DIR
elif [[ ! -d $CA_DIR ]]; then
    echo "$CA_DIR already exists but is not a directory" 1>&2
fi

cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
mv ca-key.pem $CA_DIR
mv ca.csr $CA_DIR
mv ca.pem $CA_DIR
