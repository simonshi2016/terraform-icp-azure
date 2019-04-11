

# See https://azure.microsoft.com/en-us/global-infrastructure/regions/ for details of locatiopn
variable "location" {
  description = "Region to deploy to"
  default     = "West US"
}

variable "zones" {
  description = "How many zones to deploy to within the region. If this is less than 3 availability will be limited"
  default     = "1"
}

variable "instance_name" {
  description = "Name of the deployment. Will be added to virtual machine names"
  default     = "icp"
}
# Default tags to apply to resources
variable "default_tags" {
  description = "Map of default tags to be assign to any resource that supports it"
  type    = "map"
  default = {
    Owner         = "icpuser"
    Environment   = "icp-test"
  }
}


variable "resource_group" {
  description = "Azure resource group name"
  default = "icp_rg"
}

variable "virtual_network_name" {
  description = "The name for the Azure virtual network."
  default     = "icp_vnet"
}

variable "virtual_network_cidr" {
  description = "cidr for the Azure virtual network"
  default     = "10.0.0.0/16"
}
variable "route_table_name" {
  description = "The name for the route table."
  default     = "icp_route"
}
variable "subnet_name" {
  description = "The subnet name"
  default     = "icp_subnet"
}
variable "subnet_prefix" {
  description = "The address prefix to use for the VM subnet."
  default     = "10.0.0.0/24"
}
variable "storage_account_tier" {
  description = "Defines the Tier of storage account to be created. Valid options are Standard and Premium."
  default     = "Standard"
}
variable "storage_replication_type" {
  description = "Defines the Replication Type to use for this storage account. Valid options include LRS, GRS etc."
  default     = "LRS"
}
variable "ssh_public_key" {
    description = "SSH Public Key"
    default = ""
}
variable "nfsmount" {
    default = ""
}
variable "disable_password_authentication" {
  description = "Whether to enable or disable ssh password authentication for the created Azure VMs. Default: true"
  default     = "true"

}
variable "os_image" {
  description = "Select from Ubuntu (ubuntu) or RHEL (rhel) for the Operating System"
  default     = "ubuntu"
}

variable "os_image_map" {
  description = "os image map"
  type        = "map"

  default = {
    rhel_publisher   = "RedHat"
    rhel_offer       = "RHEL"
    rhel_sku         = "7-RAW-CI"
    rhel_version     = "7.5.2018041704"
    ubuntu_publisher = "Canonical"
    ubuntu_offer     = "UbuntuServer"
    ubuntu_sku       = "16.04-LTS"
    ubuntu_version   = "latest"
  }
}
variable "admin_username" {
  description = "linux vm administrator user name"
  default     = "vmadmin"
}

##### ICP Configurations ######
variable "network_cidr" {
  description = "ICP Network CIDR for PODs"
  default     = "10.0.128.0/17"
}
variable "cluster_ip_range" {
  description = "ICP Service Cluster IP Range"
  default     = "10.1.0.0/24"
}
variable "icpadmin_password" {
    description = "ICP admin password"
    default = "Passw0rdPassw0rdPassw0rdPassw0rd"
}
variable "icp_inception_image" {
    description = "ICP Inception image to use"
    default = "ibmcom-amd64/icp-inception:3.1.2"
}
variable "cluster_name" {
  description = "Deployment name for resources prefix"
  default     = "myicp"
}

# TODO: Create option to have etcd on separate VM
# TODO: Find SSD option

variable "boot" {
  type = "map"
  default = {
    nodes         = "1"
    name          = "bootnode"
    vm_size       = "Standard_A4_v2"
    os_disk_type  = "StandardSSD_LRS"
    os_disk_size  = "100"
    docker_disk_size = "100"
    docker_disk_type = "StandardSSD_LRS"
    enable_accelerated_networking = "false"
  }
}

variable "master" {
  type = "map"
  default = {
    nodes         = "3"
    name          = "master"
    vm_size       = "Standard_F16s_v2"
    os_disk_type  = "Premium_LRS"
    os_disk_size  = "250"
    docker_disk_size = "200"
    docker_disk_type = "Premium_LRS"
    etcd_data_size   = "10"
    etcd_data_type   = "Premium_LRS"
    etcd_wal_size    = "10"
    etcd_wal_type    = "Premium_LRS"
    ibm_disk_size    = "500"
    ibm_disk_type    = "Premium_LRS"   
    enable_accelerated_networking = "true"
  }
}
variable "proxy" {
  type = "map"
  default = {
    nodes         = "0"
    name          = "proxy"
    vm_size       = "Standard_D8_v3"
    os_disk_type  = "StandardSSD_LRS"
    docker_disk_size = "100"
    docker_disk_type = "StandardSSD_LRS"
    enable_accelerated_networking = "false"
  }
}
variable "management" {
  type = "map"
  default = {
    nodes         = "0"
    name          = "mgmt"
    #vm_size      = "Standard_A4_v2"
    vm_size       = "Standard_A8_v2"
    os_disk_type  = "StandardSSD_LRS"
    docker_disk_size = "200"
    docker_disk_type = "StandardSSD_LRS"
    enable_accelerated_networking = "false"
  }
}

variable "worker" {
  type = "map"
  default = {
    nodes         = "3"
    name          = "worker"
    vm_size        = "Standard_F16s_v2"
    os_disk_type  = "Premium_LRS"
    os_disk_size  = "250"
    docker_disk_size = "200"
    docker_disk_type = "Premium_LRS"
    ibm_disk_size    = "300"
    ibm_disk_type    = "Premium_LRS"
    data_disk_size  = "300"
    data_disk_type  = "Premium_LRS"
    enable_accelerated_networking = "false"
  }
}

variable "master_lb_ports" {
  description = "Ports on the master load balancer to listen to"
  type        = "list"
  default     = ["8443", "8001", "8500", "8600", "4300", "9443", "31843"]
}

variable "master_lb_additional_ports" {
  type        = "list"
  default     = []
}

variable "proxy_lb_ports" {
  description = "Ports on the master load balancer to listen to"
  type        = "list"
  default     = ["80", "443"]
}

variable "proxy_lb_additional_ports" {
  type        ="list"
  default     =[]
}

## IAM options for kubelet and controller manager
variable "aadClientId" {
  description = "aadClientId to be provided to kubernetes controller manager"
}
variable "aadClientSecret" {
  description = "aadClientSecret to be provided to kubernetes controller manager"
}
variable "subscription_id" {
  description = "azure subscription id"
}
variable "tenant_id" {
  description = "azure client tenant id"
}

variable "private_registry" {
  description = "Private docker registry where the ICP installation image is located"
  default     = ""
}

variable "registry_username" {
  description = "Username for the private docker restistry the ICP image will be grabbed from"
  default     = ""
}

variable "registry_password" {
  description = "Password for the private docker restistry the ICP image will be grabbed from"
  default     = ""
}

variable "image_location" {
  description = "Location of ICP image tarball. Assumes stored as azure blob, default value for registry install, to walkaround terraform issue"
  default     = "default"
}

variable "image_location_key" {
  description = "Access key to download the ICP image tarball"
  default     = ""
}

# The following services can be disabled for 3.1
# custom-metrics-adapter, image-security-enforcement, istio, metering, monitoring, service-catalog, storage-minio, storage-glusterfs, and vulnerability-advisor
variable "disabled_management_services" {
  description = "List of management services to disable"
  type        = "list"
  default     = ["istio", "vulnerability-advisor", "storage-glusterfs", "storage-minio"]
}

variable "image_location_icp4d" {
  description = "Location of ICP4D image tarball. Assumes stored as azure blob, default value for manuall install, equvilent to not provided, walkaround for terraform issue"
  default   = "default"
}

variable "image_location_user" {
  description = "Http Username of ICP image tarball. "
  default   = ""
}

variable "image_location_pass" {
  description = "Http Password of ICP image tarball. "
  default   = ""
}