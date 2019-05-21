terraform {
  required_version = "~> 0.11.13"
}

##################################
## Configure the provider
##################################
# Details about authentication options here: https://www.terraform.io/docs/providers/azurerm

provider "azurerm" { 
  client_id = "${var.aadClientId}"
  client_secret = "${var.aadClientSecret}"
  subscription_id = "${var.subscription_id}"
  tenant_id = "${var.tenant_id}" 
}

##################################
## Create a resource group
##################################

locals {
  rg_name="${var.resource_group == "icp_rg" ? element(concat(azurerm_resource_group.icp.*.name,list("")),0)  : element(concat(data.azurerm_resource_group.icp_existing.*.name,list("")),0)}"
  location = "${var.resource_group == "icp_rg" ? var.location : element(concat(data.azurerm_resource_group.icp_existing.*.location,list("")),0)}"
}

data "azurerm_resource_group" "icp_existing" {
  count = "${var.resource_group != "icp_rg" ? 1 : 0}"
  name = "${var.resource_group}"
}

resource "azurerm_resource_group" "icp" {
  count    = "${var.resource_group != "icp_rg" ? 0 : 1}"
  name     = "${var.resource_group}_${random_id.clusterid.id}"
  location = "${var.location}"

  tags = "${merge(
    var.default_tags, map(
      "Clusterid", "${random_id.clusterid.hex}",
      "Name", "${var.instance_name}"
    )
  )}"
}

##################################
## Create the SSH key terraform will use for installation
##################################
resource "tls_private_key" "installkey" {
  algorithm   = "RSA"
}

##################################
## Create a random id to uniquely identifying cluster
##################################
resource "random_id" "clusterid" {
  byte_length = 4
}

locals {

  # This is just to have a long list of disabled items to use in icp-deploy.tf
  disabled_list = "${list("disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled","disabled")}"

  disabled_management_services = "${zipmap(var.disabled_management_services, slice(local.disabled_list, 0, length(var.disabled_management_services)))}"
}
