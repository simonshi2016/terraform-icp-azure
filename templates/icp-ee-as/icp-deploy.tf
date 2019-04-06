##################################
## This module handles all the ICP confifguration
## and prerequisites setup
##################################

# TODO: Add azure-disk and azure-file volumes

data "azurerm_client_config" "client_config" {}

locals {

  # Intermediate interpolations
  credentials = "${var.registry_username != "" ? join(":", list("${var.registry_username}"), list("${var.registry_password}")) : ""}"
  cred_reg   = "${local.credentials != "" ? join("@", list("${local.credentials}"), list("${var.private_registry}")) : ""}"

  # Inception image formatted for ICP deploy module
  inception_image = "${local.cred_reg != "" ? join("/", list("${local.cred_reg}"), list("${var.icp_inception_image}")) : var.icp_inception_image}"
  ssh_user = "icpdeploy"
  ssh_key = "${tls_private_key.installkey.private_key_pem}"
  image_location   = "${var.image_location != "default" && substr(var.image_location,0,5) == "https" && var.image_location_key == "" ? var.image_location : 
                        var.image_location != "default" && var.image_location_key == "" ? "${element(concat(azurerm_storage_blob.icpimage.*.url, list("")),0)}" : ""}"
  info = "${var.image_location_key != "" ? "${element(concat(null_resource.master_load_pkg.*.id, list("")),0)}" : ""}"
}

module "icpprovision" {
  source = "../../../terraform-module-icp-deploy"

  bastion_host = "${azurerm_public_ip.bootnode_pip.ip_address}"

  # Provide IP addresses for boot, master, mgmt, va, proxy and workers
  #boot-node = "${element(concat(azurerm_network_interface.boot_nic.*.private_ip_address, list("")), 0)}"
  boot-node = "${azurerm_network_interface.master_nic.0.private_ip_address}"

  icp-host-groups = {
    master      = ["${azurerm_network_interface.master_nic.*.private_ip_address}"]
    worker      = ["${azurerm_network_interface.worker_nic.*.private_ip_address}"]
    proxy       = "${slice(
      concat(azurerm_network_interface.proxy_nic.*.private_ip_address, azurerm_network_interface.master_nic.*.private_ip_address),
      0, var.proxy["nodes"] > 0 ? length(azurerm_network_interface.proxy_nic.*.private_ip_address) : length(azurerm_network_interface.master_nic.*.private_ip_address))}"
    management  = "${slice(
      concat(azurerm_network_interface.management_nic.*.private_ip_address, azurerm_network_interface.master_nic.*.private_ip_address),
      0, var.management["nodes"] > 0 ? length(azurerm_network_interface.management_nic.*.private_ip_address) : length(azurerm_network_interface.master_nic.*.private_ip_address))}"
  }

  icp-inception = "${local.inception_image}"

  # Workaround for terraform issue #10857
  # When this is fixed, we can work this out autmatically

  cluster_size  = "${var.boot["nodes"] + var.master["nodes"] + var.worker["nodes"] + var.proxy["nodes"] + var.management["nodes"]}"

  icp_configuration = {
    "network_cidr"              = "${var.network_cidr}"
    "service_cluster_ip_range"  = "${var.cluster_ip_range}"
    "ansible_user"              = "icpdeploy"
    "ansible_become"            = "true"
    "cluster_lb_address"        = "${azurerm_public_ip.master_pip.fqdn}"
    "proxy_lb_address"          = "${azurerm_public_ip.master_pip.fqdn}"
    "cluster_CA_domain"         = "${azurerm_public_ip.master_pip.fqdn}"
    "cluster_name"              = "${var.cluster_name}"

    "private_registry_enabled"  = "${var.private_registry != "" ? "true" : "false"}"
    # "private_registry_server"   = "${var.private_registry}"
    "image_repo"                = "${var.private_registry != "" ? "${var.private_registry}/${dirname(var.icp_inception_image)}" : ""}"
    "docker_username"           = "${var.registry_username}"
    "docker_password"           = "${var.registry_password}"

    # An admin password will be generated if not supplied in terraform.tfvars
    # TODO REMOVE "default_admin_password"          = "${local.icppassword}"
    "default_admin_password"    = "${var.icpadmin_password}"
    # This is the list of disabled management services
    "management_services"       = "${local.disabled_management_services}"


    "calico_ip_autodetection_method" = "first-found"
    "kubelet_nodename"          = "nodename"
    "cloud_provider"            = "azure"

    # If you want to use calico in policy only mode and Azure routed routes.
    "kube_controller_manager_extra_args" = ["--allocate-node-cidrs=true"]
    "kubelet_extra_args" = ["--enable-controller-attach-detach=true"]

    # Azure specific configurations
    # We don't need ip in ip with Azure networking
    "calico_ipip_enabled"       = "false"
    # Settings for patched icp-inception
    "calico_networking_backend"  = "none"
    "calico_ipam_type"           = "host-local"
    "calico_ipam_subnet"         = "usePodCidr"
    # Try this later: "calico_cluster_type" = "k8s"
    "etcd_extra_args"             = [
      "--grpc-keepalive-timeout=0",
      "--grpc-keepalive-interval=0",
      "--snapshot-count=10000",
      "--heartbeat-interval=250",
      "--election-timeout=1250"
    ]
    "azure"                  = {

      "cloud_provider_conf" = {
          "cloud"               = "AzurePublicCloud"
          "useInstanceMetadata" = "true"
          "tenantId"            = "${data.azurerm_client_config.client_config.tenant_id}"
          "subscriptionId"      = "${data.azurerm_client_config.client_config.subscription_id}"
          "resourceGroup"       = "${azurerm_resource_group.icp.name}"
          "useManagedIdentityExtension" = "true"
      }

      "cloud_provider_controller_conf" = {
          "cloud"               = "AzurePublicCloud"
          "useInstanceMetadata" = "true"
          "tenantId"            = "${data.azurerm_client_config.client_config.tenant_id}"
          "subscriptionId"      = "${data.azurerm_client_config.client_config.subscription_id}"
          "resourceGroup"       = "${azurerm_resource_group.icp.name}"
          "aadClientId"         = "${var.aadClientId}"
          "aadClientSecret"     = "${var.aadClientSecret}"
          "location"            = "${azurerm_resource_group.icp.location}"
          "subnetName"          = "${azurerm_subnet.container_subnet.name}"
          "vnetName"            = "${azurerm_virtual_network.icp_vnet.name}"
          "vnetResourceGroup"   = "${azurerm_resource_group.icp.name}"
          "routeTableName"      = "${azurerm_route_table.routetb.name}"
          "cloudProviderBackoff"        = "false"
          "loadBalancerSku"             = "Standard"
          "primaryAvailabilitySetName"  = "${basename(element(azurerm_virtual_machine.worker.*.availability_set_id, 0))}"# "workers_availabilityset"
          "securityGroupName"           = "${azurerm_network_security_group.worker_sg.name}"# "hktest-worker-sg"
          "excludeMasterFromStandardLB" = "true"
          "useManagedIdentityExtension" = "false"
      }
    }

    # We'll insert a dummy value here to create an implicit dependency on VMs in Terraform
    "dummy_waitfor" = "${length(concat(azurerm_virtual_machine.boot.*.id, azurerm_virtual_machine.master.*.id, azurerm_virtual_machine.worker.*.id, azurerm_virtual_machine.management.*.id))}"
  }

  generate_key = true

  # delegate the image load to module
  image_location      = "${local.image_location}"
  image_location_user = "${var.image_location_user}"
  image_location_pass = "${var.image_location_pass}"

  ssh_user         = "${local.ssh_user}"
  ssh_key_base64   = "${base64encode(local.ssh_key)}"
  ssh_agent	       = "false"

  hooks = {
    "cluster-preconfig"  = ["echo ${local.image_location}"]
    "cluster-postconfig" = ["echo -n"]
    "boot-preconfig"     = ["echo -n"]
    "preinstall"         = ["echo ${local.info}"]
    "postinstall"        = ["echo -n"]
  }
}
