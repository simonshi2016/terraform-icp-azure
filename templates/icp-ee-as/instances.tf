
##################################
## Create Availability Sets
##################################


resource "azurerm_availability_set" "controlplane" {
  name                = "controlpane_availabilityset"
  location            = "${azurerm_resource_group.icp.location}"
  resource_group_name = "${azurerm_resource_group.icp.name}"
  managed             = true

  tags {
    environment = "Production"
  }
}

resource "azurerm_availability_set" "management" {
  name                = "management_availabilityset"
  location            = "${azurerm_resource_group.icp.location}"
  resource_group_name = "${azurerm_resource_group.icp.name}"
  managed             = true

  tags {
    environment = "Production"
  }
}

resource "azurerm_availability_set" "proxy" {
  name                = "proxy_availabilityset"
  location            = "${azurerm_resource_group.icp.location}"
  resource_group_name = "${azurerm_resource_group.icp.name}"
  managed             = true

  tags {
    environment = "Production"
  }
}
#
#
resource "azurerm_availability_set" "workers" {
  name                = "workers_availabilityset"
  location            = "${azurerm_resource_group.icp.location}"
  resource_group_name = "${azurerm_resource_group.icp.name}"
  managed             = true

  tags {
    environment = "Production"
  }
}

##################################
## Create Boot VM
##################################
resource "azurerm_virtual_machine" "boot" {
  count                 = "${var.boot["nodes"]}"
  name                  = "${var.boot["name"]}${count.index + 1}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.icp.name}"
  vm_size               = "${var.boot["vm_size"]}"
  network_interface_ids = ["${element(azurerm_network_interface.boot_nic.*.id, count.index)}"]

  # The SystemAssigned identity enables the Azure Cloud Provider to use ManagedIdentityExtension
  identity = {
    type = "SystemAssigned"
  }


  storage_image_reference {
    publisher = "${lookup(var.os_image_map, join("_publisher", list(var.os_image, "")))}"
    offer     = "${lookup(var.os_image_map, join("_offer", list(var.os_image, "")))}"
    sku       = "${lookup(var.os_image_map, join("_sku", list(var.os_image, "")))}"
    version   = "${lookup(var.os_image_map, join("_version", list(var.os_image, "")))}"
  }

  storage_os_disk {
    name              = "${var.boot["name"]}-osdisk-${count.index + 1}"
    managed_disk_type = "${var.boot["os_disk_type"]}"
    disk_size_gb      = "${var.boot["os_disk_size"]}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
  }

  storage_data_disk {
    name              = "${var.proxy["name"]}-dockerdisk-${count.index + 1}"
    managed_disk_type = "${var.proxy["docker_disk_type"]}"
    disk_size_gb      = "${var.proxy["docker_disk_size"]}"
    caching           = "ReadWrite"
    create_option     = "Empty"
    lun               = 1
  }

  os_profile {
    computer_name  = "${var.boot["name"]}${count.index + 1}"
    admin_username = "${var.admin_username}"
    custom_data    = "${data.template_cloudinit_config.bootconfig.rendered}"
  }

  os_profile_linux_config {
    disable_password_authentication = "${var.disable_password_authentication}"
    ssh_keys {
      key_data = "${var.ssh_public_key}"
      path = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }
}

##################################
## Create Master VM
##################################
resource "azurerm_virtual_machine" "master" {
  depends_on            = ["azurerm_storage_blob.icpimage"]
  count                 = "${var.master["nodes"]}"
  name                  = "${var.master["name"]}${count.index + 1}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.icp.name}"
  vm_size               = "${var.master["vm_size"]}"
  network_interface_ids = ["${element(azurerm_network_interface.master_nic.*.id, count.index)}"]

  # The SystemAssigned identity enables the Azure Cloud Provider to use ManagedIdentityExtension
  identity = {
    type = "SystemAssigned"
  }

  availability_set_id = "${azurerm_availability_set.controlplane.id}"
  #zones               = ["${count.index % var.zones + 1}"]

  storage_image_reference {
    publisher = "${lookup(var.os_image_map, join("_publisher", list(var.os_image, "")))}"
    offer     = "${lookup(var.os_image_map, join("_offer", list(var.os_image, "")))}"
    sku       = "${lookup(var.os_image_map, join("_sku", list(var.os_image, "")))}"
    version   = "${lookup(var.os_image_map, join("_version", list(var.os_image, "")))}"
  }

  storage_os_disk {
    name              = "${var.master["name"]}-osdisk-${count.index + 1}"
    managed_disk_type = "${var.master["os_disk_type"]}"
    disk_size_gb      = "${var.master["os_disk_size"]}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
  }

  # Docker disk
  storage_data_disk {
    name              = "${var.master["name"]}-dockerdisk-${count.index + 1}"
    managed_disk_type = "${var.master["docker_disk_type"]}"
    disk_size_gb      = "${var.master["docker_disk_size"]}"
    caching           = "ReadWrite"
    create_option     = "Empty"
    lun               = 1
  }

 # data disk
  storage_data_disk {
    name              = "${var.master["name"]}-ibmdisk-${count.index + 1}"
    managed_disk_type = "${var.master["ibm_disk_type"]}"
    disk_size_gb      = "${var.master["ibm_disk_size"]}"
    caching           = "ReadWrite"
    create_option     = "Empty"
    lun               = 2
  }

  # ETCD Data disk
  storage_data_disk {
    name              = "${var.master["name"]}-etcddata-${count.index + 1}"
    managed_disk_type = "${var.master["etcd_data_type"]}"
    disk_size_gb      = "${var.master["etcd_data_size"]}"
    caching           = "ReadWrite"
    create_option     = "Empty"
    lun               = 3
  }

  # ETCD WAL disk
  storage_data_disk {
    name              = "${var.master["name"]}-etcdwal-${count.index + 1}"
    managed_disk_type = "${var.master["etcd_wal_type"]}"
    disk_size_gb      = "${var.master["etcd_wal_size"]}"
    caching           = "ReadWrite"
    create_option     = "Empty"
    lun               = 4
  }

  os_profile {
    computer_name  = "${var.master["name"]}${count.index + 1}"
    admin_username = "${var.admin_username}"
    custom_data    = "${element(data.template_cloudinit_config.masterconfig.*.rendered,count.index)}"
  }

  os_profile_linux_config {
    disable_password_authentication = "${var.disable_password_authentication}"
    ssh_keys {
      key_data = "${var.ssh_public_key}"
      path = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }
}

locals {
  image_location_icp4d="${var.image_location_icp4d != "default" && substr(var.image_location_icp4d,0,5) == "https" ? "var.image_location_icp4d" : var.image_location_icp4d != "default" ? "${azurerm_storage_blob.icp4dimage.url}" : ""}"
}

resource "null_resource" "master_icp4d_install" {
  depends_on=["azurerm_virtual_machine.boot","azurerm_virtual_machine.master","azurerm_storage_blob.icp4dimage"]

  connection {
    host = "${azurerm_network_interface.master_nic.0.private_ip_address}"
    user = "icpdeploy"
    private_key = "${tls_private_key.installkey.private_key_pem}"
    agent = "false"
    bastion_host="${element(azurerm_public_ip.bootnode_pip.*.ip_address,0)}"
  }

  # "echo" for creating dependency on module output, v0.12 has explicit depends_on=["module.icpprovision.install_complete"]
  provisioner "remote-exec" {
    inline = [
      "echo ${module.icpprovision.install_complete}",
      "sudo bash /tmp/generate_wdp_conf.sh '${azurerm_public_ip.master_pip.fqdn}' '${local.ssh_user}' '${local.ssh_key}' '${local.image_location_icp4d}' '${var.nfsmount}'"
    ]
  }
}

##################################
## Create Proxy VM
##################################
resource "azurerm_virtual_machine" "proxy" {
  count                 = "${var.proxy["nodes"]}"
  name                  = "${var.proxy["name"]}${count.index + 1}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.icp.name}"
  vm_size               = "${var.proxy["vm_size"]}"
  network_interface_ids = ["${element(azurerm_network_interface.proxy_nic.*.id, count.index)}"]

  # The SystemAssigned identity enables the Azure Cloud Provider to use ManagedIdentityExtension
  identity = {
    type = "SystemAssigned"
  }

  availability_set_id = "${azurerm_availability_set.proxy.id}"
  # zones               = ["${count.index % var.zones + 1}"]

  storage_image_reference {
    publisher = "${lookup(var.os_image_map, join("_publisher", list(var.os_image, "")))}"
    offer     = "${lookup(var.os_image_map, join("_offer", list(var.os_image, "")))}"
    sku       = "${lookup(var.os_image_map, join("_sku", list(var.os_image, "")))}"
    version   = "${lookup(var.os_image_map, join("_version", list(var.os_image, "")))}"
  }

  storage_os_disk {
    name              = "${var.proxy["name"]}-osdisk-${count.index + 1}"
    managed_disk_type = "${var.proxy["os_disk_type"]}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
  }

  # storage_data_disk {
  #   name              = "${var.proxy["name"]}-dockerdisk-${count.index + 1}"
  #   managed_disk_type = "${var.proxy["docker_disk_type"]}"
  #   disk_size_gb      = "${var.proxy["docker_disk_size"]}"
  #   caching           = "ReadWrite"
  #   create_option     = "Empty"
  #   lun               = 1
  # }

  os_profile {
    computer_name  = "${var.proxy["name"]}${count.index + 1}"
    admin_username = "${var.admin_username}"
    custom_data    = "${data.template_cloudinit_config.workerconfig.rendered}"
  }

  os_profile_linux_config {
    disable_password_authentication = "${var.disable_password_authentication}"
    ssh_keys {
      key_data = "${var.ssh_public_key}"
      path = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }
}

##################################
## Create Management VM
##################################
resource "azurerm_virtual_machine" "management" {
  count                 = "${var.management["nodes"]}"
  name                  = "${var.management["name"]}${count.index + 1}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.icp.name}"
  vm_size               = "${var.management["vm_size"]}"
  network_interface_ids = ["${element(azurerm_network_interface.management_nic.*.id, count.index)}"]

  # The SystemAssigned identity enables the Azure Cloud Provider to use ManagedIdentityExtension
  identity = {
    type = "SystemAssigned"
  }

  availability_set_id = "${azurerm_availability_set.management.id}"
  # zones               = ["${count.index % var.zones + 1}"]

  storage_image_reference {
    publisher = "${lookup(var.os_image_map, join("_publisher", list(var.os_image, "")))}"
    offer     = "${lookup(var.os_image_map, join("_offer", list(var.os_image, "")))}"
    sku       = "${lookup(var.os_image_map, join("_sku", list(var.os_image, "")))}"
    version   = "${lookup(var.os_image_map, join("_version", list(var.os_image, "")))}"
  }

  storage_os_disk {
    name              = "${var.management["name"]}-osdisk-${count.index + 1}"
    managed_disk_type = "${var.management["os_disk_type"]}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
  }

  # storage_data_disk {
  #   name              = "${var.management["name"]}-dockerdisk-${count.index + 1}"
  #   managed_disk_type = "${var.management["docker_disk_type"]}"
  #   disk_size_gb      = "${var.management["docker_disk_size"]}"
  #   caching           = "ReadWrite"
  #   create_option     = "Empty"
  #   lun               = 1
  # }

  os_profile {
    computer_name  = "${var.management["name"]}${count.index + 1}"
    admin_username = "${var.admin_username}"
    custom_data    = "${data.template_cloudinit_config.workerconfig.rendered}"
  }

  os_profile_linux_config {
    disable_password_authentication = "${var.disable_password_authentication}"
    ssh_keys {
      key_data = "${var.ssh_public_key}"
      path = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }
}


##################################
## Create Worker VM
##################################
resource "azurerm_virtual_machine" "worker" {
  depends_on            = ["azurerm_storage_blob.icpimage"]
  count                 = "${var.worker["nodes"]}"
  name                  = "${var.worker["name"]}${count.index + 1}"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.icp.name}"
  vm_size               = "${var.worker["vm_size"]}"
  network_interface_ids = ["${element(azurerm_network_interface.worker_nic.*.id, count.index)}"]

  # The SystemAssigned identity enables the Azure Cloud Provider to use ManagedIdentityExtension
  identity = {
    type = "SystemAssigned"
  }

  availability_set_id = "${azurerm_availability_set.workers.id}"
  # zones               = ["${count.index % var.zones + 1}"]

  storage_image_reference {
    publisher = "${lookup(var.os_image_map, join("_publisher", list(var.os_image, "")))}"
    offer     = "${lookup(var.os_image_map, join("_offer", list(var.os_image, "")))}"
    sku       = "${lookup(var.os_image_map, join("_sku", list(var.os_image, "")))}"
    version   = "${lookup(var.os_image_map, join("_version", list(var.os_image, "")))}"
  }

  storage_os_disk {
    name              = "${var.worker["name"]}-osdisk-${count.index + 1}"
    managed_disk_type = "${var.worker["os_disk_type"]}"
    disk_size_gb      = "${var.worker["os_disk_size"]}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
  }

  storage_data_disk {
    name              = "${var.worker["name"]}-dockerdisk-${count.index + 1}"
    managed_disk_type = "${var.worker["docker_disk_type"]}"
    disk_size_gb      = "${var.worker["docker_disk_size"]}"
    caching           = "ReadWrite"
    create_option     = "Empty"
    lun               = 1
  }

  storage_data_disk {
    name              = "${var.worker["name"]}-ibmdisk-${count.index + 1}"
    managed_disk_type = "${var.worker["ibm_disk_type"]}"
    disk_size_gb      = "${var.worker["ibm_disk_size"]}"
    caching           = "ReadWrite"
    create_option     = "Empty"
    lun               = 2
  }

  storage_data_disk {
    name              = "${var.worker["name"]}-datadisk-${count.index + 1}"
    managed_disk_type = "${var.worker["data_disk_type"]}"
    disk_size_gb      = "${var.worker["data_disk_size"]}"
    caching           = "ReadWrite"
    create_option     = "Empty"
    lun               = 3
  }

  os_profile {
    computer_name  = "${var.worker["name"]}${count.index + 1}"
    admin_username = "${var.admin_username}"
    custom_data    = "${data.template_cloudinit_config.workerconfig.rendered}"
  }

  os_profile_linux_config {
    disable_password_authentication = "${var.disable_password_authentication}"
    ssh_keys {
      key_data = "${var.ssh_public_key}"
      path = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }
}

