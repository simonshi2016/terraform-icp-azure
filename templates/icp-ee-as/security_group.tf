locals {
  proxy_lb_sg_ports ="${concat(var.proxy_lb_ports,var.proxy_lb_additional_ports)}"
  master_lb_merged_ports="${concat(var.master_lb_ports,var.master_lb_additional_ports)}"
  # workaround for using list under condition
  master_lb_sg_ports="${split(",",var.proxy["nodes"]=="0" ? join(",",concat(local.master_lb_merged_ports,local.proxy_lb_sg_ports)) : join(",",local.master_lb_merged_ports))}"
}

#Network Security Group - BootNode
resource "azurerm_network_security_group" "boot_sg" {
  name                = "${var.cluster_name}-${var.boot["name"]}-sg"
  location            = "${local.location}"
  resource_group_name = "${local.rg_name}"

  security_rule {
    name                       = "${var.cluster_name}-${var.boot["name"]}-ssh"
    description                = "Allow inbound SSH from all locations"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#Network Security Group - Master
resource "azurerm_network_security_group" "master_sg" {
  name                = "${var.cluster_name}-${var.master["name"]}-sg"
  location            = "${local.location}"
  resource_group_name = "${local.rg_name}"

  security_rule {
    name                       = "${var.cluster_name}-${var.proxy["name"]}-nodeport"
    description                = "Allow inbound Nodeport from all locations"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30000-32767"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                        = "${var.cluster_name}-${var.master["name"]}-outbound"
    priority                    = 100
    direction                   = "Outbound"
    access                      = "Allow"
    protocol                    = "*"
    source_port_range           = "*"
    destination_port_range      = "*"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
  }
}

resource "azurerm_network_security_rule" "master_lb_sg_inbound_rule" {
    count                      = "${length(local.master_lb_sg_ports)}"
    name                       = "${var.cluster_name}-${var.master["name"]}-port-${local.master_lb_sg_ports[count.index]}"
    description                = "Port ${local.master_lb_sg_ports[count.index]}"
    priority                   = "${200+count.index*100}"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "${local.master_lb_sg_ports[count.index]}"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    resource_group_name         = "${local.rg_name}"
    network_security_group_name = "${azurerm_network_security_group.master_sg.name}"
}

#Network Security Group - Proxy
resource "azurerm_network_security_group" "proxy_sg" {
  name                = "${var.cluster_name}-${var.proxy["name"]}-sg"
  location            = "${local.location}"
  resource_group_name = "${local.rg_name}"

  security_rule  {
    name                       = "${var.cluster_name}-${var.proxy["name"]}-nodeport"
    description                = "Allow inbound Nodeport from all locations"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30000-32767"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_rule" "proxy_lb_sg_inbound_rule" {
    count                      = "${length(local.proxy_lb_sg_ports)}"
    name                       = "${var.cluster_name}-${var.master["name"]}-port-${local.proxy_lb_sg_ports[count.index]}"
    description                = "Port ${local.proxy_lb_sg_ports[count.index]}"
    priority                   = "${200+count.index*100}"
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "${local.proxy_lb_sg_ports[count.index]}"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    resource_group_name         = "${local.rg_name}"
    network_security_group_name = "${azurerm_network_security_group.proxy_sg.name}"
}

#Network Security Group - Management and Worker
resource "azurerm_network_security_group" "worker_sg" {
  name                = "${var.cluster_name}-worker-sg"
  location            = "${local.location}"
  resource_group_name = "${local.rg_name}"

  # security_rule {
  #   name                       = "${var.cluster_name}-worker-ssh"
  #   description                = "Allow inbound SSH from all locations"
  #   priority                   = 100
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "22"
  #   source_address_prefix      = "*"
  #   destination_address_prefix = "*"
  # }
}
