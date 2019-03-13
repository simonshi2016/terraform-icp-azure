#!/bin/bash

if [[ ! -f key ]];then
  echo -e "$(cat terraform.tfstate | jq -r '.modules[0].resources."tls_private_key.installkey".primary.attributes.private_key_pem')" > tmp_key && chmod 0600 tmp_key
fi
node="boot"
pubIpFile="tmp_publicIp_boot"
if [[ $1 == "master" ]];then
  node="control"
  pubIpFile="tmp_publicIp_master"
fi

if [[ ! -f "$pubIpFile" ]];then
  id=$(az network public-ip list | jq -r '.[].id' | grep $node)
  publicIp=$(az network public-ip show --ids $id | jq -r '.ipAddress')
  echo $publicIp > $pubIpFile
fi
publicIp=$(cat $pubIpFile)
conn="ssh"
if [[ "$2" == "sftp" ]];then
   conn="sftp"
fi
eval "$conn -o StrictHostKeyChecking=no -i tmp_key icpdeploy@$publicIp"
