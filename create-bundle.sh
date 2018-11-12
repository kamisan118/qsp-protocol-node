#!/bin/bash

set -e
readonly ZIP_FILENAME=qsp-protocol-v1.zip

make clean test-docker
docker save -o deployment/local/app.tar qsp-protocol-node:latest

cd ./deployment/local
echo "Switched to: `pwd`"
if [ ! -f config.yaml ] && [ ! -f run.sh ] && [ ! -f app.tar ]; then
        echo "Require both config.yaml and run.sh"
        exit 1
fi

sed -n -i.org '/mainnet/,$p' config.yaml 
sed -i.org 's/testnet/mainnet/g' run.sh

cp ../../LICENSE .

zip -r $ZIP_FILENAME . -x *.org* 
mv config.yaml.org config.yaml
mv run.sh.org run.sh
rm LICENSE