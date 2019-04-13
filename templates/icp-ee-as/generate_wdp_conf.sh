#!/bin/bash
lb=$1
cluster_domain=$1
ssh_user=$2
ssh_key=$3
nfs_mount=$4

function getIPs {
    for i in $(cat /opt/ibm/cluster/hosts); do
    if [[ $i =~ [A-Za-z]+ ]];then
        master_count=-1
        worker_count=-1
        if [[ $i =~ master ]];then
        master_count=0
        fi
        if [[ $i =~ worker ]];then
        worker_count=0
        fi
        continue
    fi

    if [[ $master_count -ge 0 ]];then
        masters[$master_count]=$i
        ((master_count++))
    fi

    if [[ $worker_count -ge 0 ]];then
        workers[$worker_count]=$i
        ((worker_count++))
    fi
    done
}


getIPs

echo -e "${ssh_key}" > /root/.ssh/installkey
chmod 600 /root/.ssh/installkey
echo "ssh_key=/root/.ssh/installkey" > /tmp/wdp.conf
echo "virtual_ip_address_1=${lb}" >> /tmp/wdp.conf
echo "virtual_ip_address_2=${lb}" >> /tmp/wdp.conf

master1_node=${masters[0]}

for((i=0;i<${#masters[@]};i++));do
    echo "master_node_$((i+1))=${masters[i]}" >> /tmp/wdp.conf
    echo "master_node_path_$((i+1))=/ibm" >> /tmp/wdp.conf
done

for((i=0;i<${#workers[@]};i++));do
    echo "worker_node_$((i+1))=${workers[i]}" >> /tmp/wdp.conf
    if [[ "$nfs_mount" == "" ]] && [[ $i -lt 3 ]];then
        echo "worker_node_data_$((i+1))=/data" >> /tmp/wdp.conf
    fi
    echo "worker_node_path_$((i+1))=/ibm" >> /tmp/wdp.conf
done

if [[ "$nfs_mount" != "" ]];then
    echo $nfs_mount | awk -F: '{print "nfs_server="$1"\nnfs_dir="$2}' >> /tmp/wdp.conf
fi

echo "ssh_port=22" >> /tmp/wdp.conf
echo "suppress_warning=true" >> /tmp/wdp.conf

# add cloud additional data
admin_pwd=$(grep default_admin_password /opt/ibm/cluster/config.yaml | awk -F: '{print $2}')
echo "cloud=azure" >> /tmp/wdp.conf
echo "cloud_data=${cluster_domain},${admin_pwd}" >> /tmp/wdp.conf

masterbootnode="1"

# xfer to master 1 node
echo -e "${ssh_key}" > /tmp/tmp_key
chmod 0600 /tmp/tmp_key
scp -i /tmp/tmp_key -o StrictHostKeyChecking=no /tmp/wdp.conf ${ssh_user}@${master1_node}:~/
ssh -i /tmp/tmp_key -o StrictHostKeyChecking=no ${ssh_user}@${master1_node} "sudo mv wdp.conf /ibm;sudo chown root:root /ibm/wdp.conf"

if [[ "$masterbootnode" != "1" ]];then
    tar -cvzf /tmp/icp-cluster.tar.gz /opt/ibm/cluster/cfc-certs /opt/ibm/cluster/config.yaml /opt/ibm/cluster/hosts
    scp -i /tmp/tmp_key -o StrictHostKeyChecking=no /tmp/icp-cluster.tar.gz ${ssh_user}@${master1_node}:/tmp
    ssh -i /tmp/tmp_key -o StrictHostKeyChecking=no ${ssh_user}@${master1_node} "sudo mkdir -p /opt/ibm/cluster; if [ ! -f /opt/ibm/cluster/config.yaml ];then sudo tar -xvzf /tmp/icp-cluster.tar.gz -C /;fi"
fi

rm -rf /tmp/tmp_key

