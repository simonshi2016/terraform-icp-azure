#!/bin/bash

image_location=$1
image_location_key=$2

cd /tmp
wget -O azcopy.tar.gz https://aka.ms/downloadazcopylinux64
tar -xf azcopy.tar.gz
sudo ./install.sh > /dev/null

echo "copying image..."
image_file="$(basename $image_location)"
mkdir -p /opt/ibm/cluster/images
azcopy --source $image_location --source-key $image_location_key --destination /opt/ibm/cluster/images/$image_file > /dev/null

# For now we need to install docker here, line up with 3.0.2 plugin
echo "Installing Docker.."
wget https://raw.githubusercontent.com/ibm-cloud-architecture/terraform-module-icp-deploy/3.0.2/scripts/boot-master/install-docker.sh
chmod a+x install-docker.sh
sudo chmod 777 /tmp
./install-docker.sh -i docker-ce -v latest

echo "loading package..."
cd /opt/ibm/cluster/images/
tar -xzf $image_file -O | docker load >&2
touch .load_package_finished
