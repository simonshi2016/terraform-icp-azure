#!/bin/bash
clusterIps=$1
ssh_user=$2
ssh_key=$3
icp_inception_image=$4

logfile=/tmp/waitfornodes.log
function log() {
    echo "$(date): $1" | tee -a $logfile
}

log "wait for boot master to become available"
while [ ! -f /var/lib/cloud/instance/boot-finished ];do sleep 30; done
log "boot master is ready"

log "wait for all nodes ready"
echo $clusterIps | tr ',' '\n' >> /opt/ibm/cluster/clusterips
echo -e "${ssh_key}" > /opt/ibm/cluster/installkey
chmod 400 /opt/ibm/cluster/installkey

master1=`ip route get 8.8.8.8 | awk 'NR==1 {print $NF}'`
docker run \
-e ANSIBLE_HOST_KEY_CHECKING=false \
-v /opt/ibm/cluster:/installer/cluster \
--entrypoint ansible \
--net=host \
-t \
$icp_inception_image \
-i /installer/cluster/clusterips all:\!$master1 \
--private-key /installer/cluster/installkey \
-u ${ssh_user} \
-b \
-m wait_for \
-a "path=/var/lib/cloud/instance/boot-finished timeout=18000" | tee -a $logfile

log "all nodes ready"
rm -rf /opt/ibm/cluster/installkey
rm -rf /opt/ibm/cluster/clusterips