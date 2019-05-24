#######
## Load balancers and rules
######
locals {
  proxy_lb_ports ="${concat(var.proxy_lb_ports,var.proxy_lb_additional_ports)}"
  master_lb_ports="${concat(var.master_lb_ports,var.master_lb_additional_ports)}"
}

resource "azurerm_lb" "controlplane" {
  depends_on          = ["azurerm_public_ip.master_pip"]
  name                = "ControlPlaneLB"
  location            = "${var.location}"
  sku                 = "Standard"
  resource_group_name = "${local.rg_name}"

  frontend_ip_configuration {
    name                 = "MasterIPAddress"
    public_ip_address_id = "${azurerm_public_ip.master_pip.id}"
  }
}


# # Use NAT for SSH to avoid extra bastion host
# resource "azurerm_lb_nat_rule" "ssh_nat" {
#   resource_group_name            = "${local.rg_name}"
#   loadbalancer_id                = "${azurerm_lb.controlplane.id}"
#   name                           = "SSHAccess"
#   protocol                       = "Tcp"
#   frontend_port                  = 22
#   backend_port                   = 22
#   frontend_ip_configuration_name = "MasterIPAddress"
# }

resource "azurerm_lb_probe" "master_lb_port_probe" {
  count               = "${length(local.master_lb_ports)}"
  resource_group_name = "${local.rg_name}"
  loadbalancer_id     = "${azurerm_lb.controlplane.id}"
  name                = "Masterportprobe${local.master_lb_ports[count.index]}"
  port                = "${local.master_lb_ports[count.index]}"
}

# Create a rule per port in var.master_lb_ports
resource "azurerm_lb_rule" "master_rule" {
  count                          = "${length(local.master_lb_ports)}"
  resource_group_name            = "${local.rg_name}"
  loadbalancer_id                = "${azurerm_lb.controlplane.id}"
  name                           = "Masterport${local.master_lb_ports[count.index]}"
  protocol                       = "Tcp"
  frontend_port                  = "${local.master_lb_ports[count.index]}"
  backend_port                   = "${local.master_lb_ports[count.index]}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.masterlb_pool.id}"
  frontend_ip_configuration_name = "MasterIPAddress"
  load_distribution              = "${var.lb_probe_load_distribution}"
  probe_id                       = "${element(concat(azurerm_lb_probe.master_lb_port_probe.*.id,list("")), count.index)}"
}

# To activate SNAT outbound port on LB for NTP
resource "azurerm_lb_rule" "master_rule_udp" {
  count                          = "${length(var.master_lb_ports_udp)}"
  resource_group_name            = "${local.rg_name}"
  loadbalancer_id                = "${azurerm_lb.controlplane.id}"
  name                           = "Masterport${var.master_lb_ports_udp[count.index]}"
  protocol                       = "Udp"
  frontend_port                  = "${var.master_lb_ports_udp[count.index]}"
  backend_port                   = "${var.master_lb_ports_udp[count.index]}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.masterlb_pool.id}"
  frontend_ip_configuration_name = "MasterIPAddress"
}

resource "azurerm_lb_backend_address_pool" "masterlb_pool" {
  resource_group_name = "${local.rg_name}"
  loadbalancer_id     = "${azurerm_lb.controlplane.id}"
  name                = "MasterAddressPool"
}

# Associate masters with master LB
resource "azurerm_network_interface_backend_address_pool_association" "masterlb" {
  count                   = "${var.master["nodes"]}"
  network_interface_id    = "${element(azurerm_network_interface.master_nic.*.id, count.index)}"
  ip_configuration_name   = "MasterIPAddress"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.masterlb_pool.id}"
}

# # Only NAT SSH to first master
# resource "azurerm_network_interface_nat_rule_association" "ssh" {
#   network_interface_id  = "${azurerm_network_interface.boot_nic.0.id}"
#   ip_configuration_name = "BootIPAddress"
#   nat_rule_id           = "${azurerm_lb_nat_rule.ssh_nat.id}"
# }

# Create a rule per port in var.proxy_lb_ports
resource "azurerm_lb_rule" "proxy_rule" {
  count                          = "${length(local.proxy_lb_ports)}"
  resource_group_name            = "${local.rg_name}"
  loadbalancer_id                = "${azurerm_lb.controlplane.id}"
  name                           = "Proxyport${local.proxy_lb_ports[count.index]}"
  protocol                       = "Tcp"
  frontend_port                  = "${local.proxy_lb_ports[count.index]}"
  backend_port                   = "${local.proxy_lb_ports[count.index]}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.proxylb_pool.id}"
  frontend_ip_configuration_name = "MasterIPAddress"
}

resource "azurerm_lb_backend_address_pool" "proxylb_pool" {
  resource_group_name = "${local.rg_name}"
  loadbalancer_id     = "${azurerm_lb.controlplane.id}"
  name                = "ProxyAddressPool"
}

# Associate proxies with proxy LB
resource "azurerm_network_interface_backend_address_pool_association" "proxylb" {
  count                   = "${var.proxy["nodes"] != "0" ? var.proxy["nodes"] : var.master["nodes"]}"
  network_interface_id    = "${element(concat(azurerm_network_interface.proxy_nic.*.id,azurerm_network_interface.master_nic.*.id),count.index)}"
  ip_configuration_name   = "${var.proxy["nodes"] == "0" ? "MasterIPAddress" : "primary"}"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.proxylb_pool.id}"
}
