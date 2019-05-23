#!/bin/bash

image_location_icp4d=$1
image_location_key=$2

function installAzCopy() {
    echo "check if azcopy is installed"
    azCopyBin=$(which azcopy)
    if [[ $? -ne 0 ]];then
        echo "installing azcopy.."
        cd /tmp
        wget -O azcopy.tar.gz https://aka.ms/downloadazcopylinux64
        tar -xf azcopy.tar.gz
        ./install.sh > /tmp/azcopy_install.log
    fi
}

if [[ "$image_location_icp4d" == "" ]] || [[ "$image_location_key" == "" ]];then
    echo "icp4d is ready to be installed"
    exit 0
fi

installAzCopy

azCopyBin=$(which azcopy)
if [[ $? -ne 0 ]];then
    echo "not able to download ICP4D image, please download manually"
    exit 0
fi

icp4d_image=$(basename $image_location_icp4d)
echo "downloading ICP4D installer"
#wget -nv --continue $image_location_icp4d -O /ibm/$filename
$azCopyBin --quiet --source $image_location_icp4d --source-key $image_location_key --destination /ibm/$icp4d_image --parallel-level 8 > /tmp/icp4d_download.log
if [[ $? -ne 0 ]];then
    echo "error downloading icp4d installer, please download manually, $?"
    exit 1
fi

echo "downloading modules.."
ICP4D_MODULES=/ibm/modules
module_loc=$(dirname $image_location_icp4d)
module_loc=${module_loc}/modules/
#wget -nv --continue -r -np -R "index.html*" $module_loc
$azCopyBin --quiet --source $module_loc --source-key $image_location_key --destination $ICP4D_MODULES --recursive --parallel-level 8 > /tmp/module_download.log
if [[ $? -ne 0 ]];then
    echo "error downloading modules folder, please download manually"
fi

# check if module folder is empty
if [[ -d $ICP4D_MODULES ]] && [[ -z "$(ls -A $ICP4D_MODULES)" ]];then
    rm -rf $ICP4D_MODULES
fi

function check_install() {
    local pidFile=/var/run/icp4d.pid

    while [[ -f $pidFile ]];do
        if which docker > /dev/null 2>&1 && docker ps | grep dp-installer > /dev/null 2>&1;then
            docker_logs=$(docker logs --tail 10 dp-installer | grep -Ei 'fail' | grep -Ei 'retry' | grep -Ei 'skip')
            if [[ -n "$docker_logs" ]];then
                echo "ICP4D Installer experiencing issue and waiting for user input, You may review the installer log under /ibm/InstallPackage/tmp"
                kill -9 $(cat $pidFile)
                rm -rf $pidFile
                break
            fi
        fi
        sleep 10
    done
}

echo "installing icp4d..."
cd /ibm
chmod a+x $icp4d_image

pidFile=/var/run/icp4d.pid
rm -rf $pidFile
echo $$ > $pidFile
check_install &

./$icp4d_image --load-balancer --accept-license
if [[ $? -ne 0 ]];then
    echo "error installing icp4d,please check log under /ibm/InstallPacakge/tmp for details"
    rm -rf $pidFile
    exit 1
fi

rm -rf $pidFile