#!/bin/bash

image_location_docker=$1
image_location=$2
image_location_key=$3
icp_inception_image=$4
node_idx=$5

logfile="/tmp/load_package.log"

function log() {
    echo "$(date): $1" | tee -a $logfile
}

function install_azcopy() {
    if ! which azcopy > /dev/null 2>&1;then
        log "installing azcopy..."
        wget -O azcopy.tar.gz https://aka.ms/downloadazcopylinux64
        tar -xf azcopy.tar.gz
        sudo ./install.sh > /dev/null
    fi
}

function ubuntu_docker_install {
    docker_image=$1
    docker_version=$2
    # Process for Ubuntu VMs
    echo "Installing ${docker_version:-latest} docker from docker repository" >&2
    sudo apt-get -q update
    # Make sure preprequisites are installed
    sudo apt-get -y -q install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

    # Add docker gpg key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    # Right now hard code adding x86 repo
    sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

    sudo apt-get -q update
    sudo apt-get -y -q install ${docker_image} ${docker_version}
    if [[ $? -gt 0 ]]; then
        log "Error installing ${docker_image} ${docker_version}"
        exit 1
    fi
}

function rhel_docker_install {
    if [[ "$image_location_docker" == "" ]];then
        return
    fi

    echo "Starting installation of $image_location_docker"
    docker_install_dir=/tmp/icp-docker
    mkdir -p $docker_install_dir
    docker_filename=$(basename $image_location_docker)
    install_azcopy
    azcopy --source $image_location_docker --source-key $image_location_key --destination $docker_install_dir/$docker_filename > /dev/null

    chmod a+x $docker_install_dir/$docker_filename
    sudo $docker_install_dir/$docker_filename --install

    n=20
    while [[ $n -gt 0 ]];do 
        if systemctl is-active docker | grep active;then 
            log "Docker Started"
            break
        else 
            n=$((n-1))
            sleep 3
        fi
    done

    if [[ $n -gt 0 ]];then
        log "Docker installed but hasn't started in 60s"
    fi
}

if grep -i '^name="red hat' /etc/os-release > /dev/null;then
    os_release="RHEL"
elif grep -i '^name="Ubuntu' /etc/os-release > /dev/null;then
    os_release="Ubuntu"
else
    log "OS not supported"
    exit 1
fi

sudo chmod 777 /tmp
cd /tmp

log "Installing Docker..."
if [[ "$os_release" == "Ubuntu" ]];then
    ubuntu_docker_install docker-ce latest
elif [[ "$os_release" == "RHEL" ]];then
    rhel_docker_install
fi

if [[ "$image_location" != "" ]] && [[ "$image_location_key" != "" ]];then

    log "downloading image..."
    image_file="$(basename $image_location)"
    mkdir -p /opt/ibm/cluster/images
    install_azcopy
    azcopy --source $image_location --source-key $image_location_key --destination /opt/ibm/cluster/images/$image_file > /dev/null

    log "loading package..."
    cd /opt/ibm/cluster/images/
    tar -xzf $image_file -O | docker load >&2
    log "image loaded"
fi

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
    -a "path=/var/lib/cloud/instance/boot-finished timeout=18000" | tee -a $logfile

    log "nodes ready"
fi
