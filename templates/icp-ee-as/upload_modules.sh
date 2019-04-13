#!/bin/bash
modules_dir=modules
module_location_local=$1
module_location_remote=$2
module_location_key=$3

if [[ "$module_location_remote" == "" ]] || [[ "$module_location_local" == "" ]];then
    exit 0
fi


function installAzCopy() {
    echo "check if azcopy is installed"
    azCopyBin=$(which azcopy)
    if [[ $? -ne 0 ]];then
        echo "installing azcopy.."
        cd /tmp
        wget -O azcopy.tar.gz https://aka.ms/downloadazcopylinux64
        tar -xf azcopy.tar.gz
        sudo ./install.sh > /tmp/azcopy_install.log
    fi
}

installer_dir_local=$(dirname $module_location_local)
installer_dir_remote=$(dirname $module_location_remote)
module_location_local=${installer_dir_local}/${modules_dir}/
module_location_remote=${installer_dir_remote}/${modules_dir}/

# check if local modules dir is empty
if [[ ! -d $module_location_local ]] || [[ -z "$(ls -A $module_location_local)" ]];then
    exit 0
fi

# check and install azcopy
installAzCopy

#azcopy seems to automatically resume copy upon connection reestablish from network interuption, retry once
retry=1
if which azcopy > /dev/null;then
    while [[ $retry -ge 0 ]];do
        echo "uploading modules.."
        azcopy --quiet --source $module_location_local --destination $module_location_remote --dest-key $module_location_key --recursive --parallel-level 8 > $installer_dir_local/upload_modules.log
        if [[ $? -eq 0 ]];then
            break
        else
            retry=$(($retry-1))
        fi
    done
fi
