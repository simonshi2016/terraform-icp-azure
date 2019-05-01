#!/bin/bash

image_location=$1
image_location_key=$2
icp_inception_image=$3
node_idx=$4

logfile="/tmp/load_package.log"

function log() {
    echo "$(date): $1" | tee -a $logfile
}

sudo chmod 777 /tmp
cd /tmp
log "installing azcopy..."
wget -O azcopy.tar.gz https://aka.ms/downloadazcopylinux64
tar -xf azcopy.tar.gz
sudo ./install.sh > /dev/null

log "downloading image..."
image_file="$(basename $image_location)"
mkdir -p /opt/ibm/cluster/images
azcopy --source $image_location --source-key $image_location_key --destination /opt/ibm/cluster/images/$image_file > /dev/null

# For now we need to install docker here, line up with 3.0.2 plugin
log "Installing Docker..."
wget https://raw.githubusercontent.com/ibm-cloud-architecture/terraform-module-icp-deploy/3.0.2/scripts/boot-master/install-docker.sh
chmod a+x install-docker.sh
./install-docker.sh -i docker-ce -v latest

log "loading package..." 
cd /opt/ibm/cluster/images/
tar -xzf $image_file -O | docker load >&2
log "image loaded"

if [[ "$node_idx" == "0" ]];then
    log "waiting for nodes ready..."
    myip=`ip route get 8.8.8.8 | awk 'NR==1 {print $NF}'`

    docker run \
    -e ANSIBLE_HOST_KEY_CHECKING=false \
    -v /opt/ibm/cluster:/installer/cluster \
    --entrypoint ansible \
    --net=host \
    -t \
    $icp_inception_image \
    -i /installer/cluster/hosts all:\!$myip \
    --private-key /installer/cluster/ssh_key \
    -u icpdeploy \
    -b \
    -m wait_for \
    -a "path=/var/lib/cloud/instance/boot-finished timeout=18000" | tee $logfile

    log "nodes ready"
fi
