#!/bin/bash

icp_tarball=$1
while ! which docker > /dev/null 2>&1;do
    sleep 5
done

echo "loading package..."
image_file=$(basename $icp_tarball)
cd /opt/ibm/cluster/images/
tar -xzf ${image_file}
docker load -i ${image_file:0:-3}
touch .load_package_finished
rm -rf ${image_file:0:-3}
