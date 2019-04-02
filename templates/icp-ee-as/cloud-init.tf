
data "template_file" "common_config" {
  template = <<EOF
  #cloud-config
  package_upgrade: true
  packages:
    - cifs-utils
    - nfs-common
    - python-yaml
  disable_root: false
  users:
    - default
    - name: icpdeploy 
      groups: [ wheel ]
      sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
      shell: /bin/bash
      ssh-authorized-keys:
        - ${tls_private_key.installkey.public_key_openssh}
    - name: root
      ssh_authorized_keys:
        - ${tls_private_key.installkey.public_key_openssh}
EOF
}

data "template_file" "docker_disk" {
  template = <<EOF
#!/bin/bash
sudo mkdir -p /var/lib/docker
# Check if we have a separate docker disk, or if we should use temporary disk
if [ -e /dev/sdc ]; then
  sudo parted -s -a optimal /dev/disk/azure/scsi1/lun1 mklabel gpt -- mkpart primary xfs 1 -1
  sudo partprobe
  retry=3
  while [ $retry -gt 0 ];
  do
    if sudo mkfs.xfs -n ftype=1 /dev/disk/azure/scsi1/lun1-part1;then
      break
    fi
    sleep 2
    retry=$((retry-1))
  done
  echo "/dev/disk/azure/scsi1/lun1-part1  /var/lib/docker   xfs  defaults   0 0" | sudo tee -a /etc/fstab
else
  # Use the temporary disk
  sudo umount /mnt
  sudo sed -i 's|/mnt|/var/lib/docker|' /etc/fstab
fi
sudo mount /var/lib/docker
EOF
}

data "template_file" "etcd_disk" {
  template = <<EOF
#!/bin/bash
sudo mkdir -p /var/lib/etcd
sudo mkdir -p /var/lib/etcd-wal
etcddisk=$(ls /dev/disk/azure/*/lun3)
waldisk=$(ls /dev/disk/azure/*/lun4)

sudo parted -s -a optimal $etcddisk mklabel gpt -- mkpart primary xfs 1 -1
sudo parted -s -a optimal $waldisk mklabel gpt -- mkpart primary xfs 1 -1
sudo partprobe

retry=3
while [ $retry -gt 0 ];
do 
  if sudo mkfs.xfs -n ftype=1 $etcddisk-part1;then
    break
  fi
  sleep 2
  retry=$((retry-1))
done

retry=3
while [ $retry -gt 0 ];
do 
  if sudo mkfs.xfs -n ftype=1 $waldisk-part1;then
    break
  fi
  retry=$((retry-1))
done
echo "$etcddisk-part1  /var/lib/etcd   xfs  defaults   0 0" | sudo tee -a /etc/fstab
echo "$waldisk-part1  /var/lib/etcd-wal   xfs  defaults   0 0" | sudo tee -a /etc/fstab

sudo mount /var/lib/etcd
sudo mount /var/lib/etcd-wal
EOF
}

data "template_file" "ibm_disk" {
  template = <<EOF
#!/bin/bash
sudo mkdir -p /ibm
datadisk=$(ls /dev/disk/azure/*/lun2)

sudo parted -s -a optimal $datadisk mklabel gpt -- mkpart primary xfs 1 -1
sudo partprobe

retry=3
while [ $retry -gt 0 ];
do 
  if sudo mkfs.xfs -n ftype=1 $datadisk-part1;then
    break
  fi
  sleep 2
  retry=$((retry-1))
done
echo "$datadisk-part1  /ibm   xfs  defaults   0 0" | sudo tee -a /etc/fstab
sudo mount /ibm
EOF
}

data "template_file" "data_disk" {
  template = <<EOF
#!/bin/bash
sudo mkdir -p /data
datadisk=$(ls /dev/disk/azure/*/lun3)

sudo parted -s -a optimal $datadisk mklabel gpt -- mkpart primary xfs 1 -1
sudo partprobe

retry=3
while [ $retry -gt 0 ];
do 
  if sudo mkfs.xfs -n ftype=1 $datadisk-part1;then
    break
  fi
  sleep 2
  retry=$((retry-1))
done
echo "$datadisk-part1  /data   xfs  defaults   0 0" | sudo tee -a /etc/fstab
sudo mount /data
EOF
}

data "template_file" "load_tarball" {
  template = <<EOF
#!/bin/bash
image_file="$(basename $${tarball})"

cd /tmp
wget -O azcopy.tar.gz https://aka.ms/downloadazcopylinux64
tar -xf azcopy.tar.gz
sudo ./install.sh

mkdir -p /opt/ibm/cluster/images
azcopy --source $${tarball} --source-key $${key} --destination /opt/ibm/cluster/images/$image_file

# For now we need to install docker here, line up with 3.0.2 plugin
wget https://raw.githubusercontent.com/ibm-cloud-architecture/terraform-module-icp-deploy/3.0.2/scripts/boot-master/install-docker.sh
chmod a+x install-docker.sh
# Don't know why I need to do this first in azure
sudo chmod 777 /tmp
./install-docker.sh -i docker-ce -v latest

# Now load the docker tarball
tar xf /opt/ibm/cluster/images/$image_file -O | sudo docker load
EOF

  vars {
    tarball = "${var.image_location}"
    key     = "${var.image_location_key}"
  }
}

data "template_file" "master_config" {
  template = <<EOF
#cloud-config
write_files:
- path: /etc/smbcredentials/icpregistry.cred
  content: |
    username=$${username}
    password=$${password}
- path: /tmp/generate_wdp_conf.sh
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/generate_wdp_conf.sh"))}
mounts:
- [ ${element(split(":", azurerm_storage_share.icpregistry.url), 1)}, /var/lib/registry, cifs, "nofail,credentials=/etc/smbcredentials/icpregistry.cred,dir_mode=0777,file_mode=0777,serverino" ]
EOF

  vars {
    username= "${azurerm_storage_account.infrastructure.name}"
    password= "${azurerm_storage_account.infrastructure.primary_access_key}"
    tarball = "${var.image_location}"
    key     = "${var.image_location_key}"
  }
}

data "template_file" "master_load_tarball" {
  count = "${var.master["nodes"]}"
  template = <<EOF
#!/bin/bash
if [[ "$${master_idx}" == "0" ]] && [[ "$$tarball" != "" ]] && [[ "$$key" != "" ]];then
cd /tmp
wget -O azcopy.tar.gz https://aka.ms/downloadazcopylinux64
tar -xf azcopy.tar.gz
sudo ./install.sh

echo "copying image..."
image_file="$(basename $${tarball})"
mkdir -p /opt/ibm/cluster/images
azcopy --source $${tarball} --source-key $${key} --destination /opt/ibm/cluster/images/$image_file

# For now we need to install docker here, line up with 3.0.2 plugin
echo "Installing Docker.."
wget https://raw.githubusercontent.com/ibm-cloud-architecture/terraform-module-icp-deploy/3.0.2/scripts/boot-master/install-docker.sh
chmod a+x install-docker.sh
sudo chmod 777 /tmp
./install-docker.sh -i docker-ce -v latest
fi

tar -xzf $image_file -O | docker load >&2
touch .load_package_finished
EOF

  vars {
    master_idx = "${count.index}"
    tarball = "${substr(var.image_location,0,5) == "https" ? var.image_location : ""}"
    key     = "${var.image_location_key}"
  }
}

data "template_file" "master_script" {
  template = <<EOF
#!/bin/bash
while ! sudo mount | grep '/var/lib/registry' > /dev/null 2>&1;
do
  sudo mount /var/lib/registry
  sleep 2
done
EOF
}

data "template_cloudinit_config" "bootconfig" {
  gzip          = true
  base64_encode = true

  # Create the icpdeploy user which we will use during initial deployment of ICP.
  part {
    content_type = "text/cloud-config"
    content      =  "${data.template_file.common_config.rendered}"
  }

  # Setup the docker disk
  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.docker_disk.rendered}"
  }

  # Load the ICP Images
 # part {
 #   content_type = "text/x-shellscript"
 #   content      = "${var.image_location != "" ? data.template_file.load_tarball.rendered : "#!/bin/bash"}"
 # }
}

data "template_cloudinit_config" "masterconfig" {
  count         = "${var.master["nodes"]}"
  gzip          = true
  base64_encode = true

  # Create the icpdeploy user which we will use during initial deployment of ICP.
  part {
    content_type = "text/cloud-config"
    content      =  "${data.template_file.common_config.rendered}"
  }

  # Setup the docker disk
  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.docker_disk.rendered}"
  }

  # Setup the etcd disks
  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.etcd_disk.rendered}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.ibm_disk.rendered}"
  }

  # Setup the icp registry share
  part {
    content_type = "text/cloud-config"
    content      =  "${data.template_file.master_config.rendered}"
  }

 # part {
 #   content_type = "text/x-shellscript"
 #   content      = "${element(data.template_file.master_load_tarball.*.rendered,count.index)}"
 # }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.master_script.rendered}"
  }

}

data "template_cloudinit_config" "workerconfig" {
  gzip          = true
  base64_encode = true

  # Create the icpdeploy user which we will use during initial deployment of ICP.
  part {
    content_type = "text/cloud-config"
    content      =  "${data.template_file.common_config.rendered}"
  }

  # Setup the docker disk
  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.docker_disk.rendered}"
  }
  
  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.ibm_disk.rendered}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.data_disk.rendered}"
  }
}

