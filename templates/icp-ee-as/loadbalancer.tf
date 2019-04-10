#######
## Load balancers and rules
######
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

# Create a rule per port in var.master_lb_ports
resource "azurerm_lb_rule" "master_rule" {
  count                          = "${length(var.master_lb_ports)}"
  resource_group_name            = "${local.rg_name}"
  loadbalancer_id                = "${azurerm_lb.controlplane.id}"
  name                           = "Masterport${element(var.master_lb_ports, count.index)}"
  protocol                       = "Tcp"
  frontend_port                  = "${element(var.master_lb_ports, count.index)}"
  backend_port                   = "${element(var.master_lb_ports, count.index)}"
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

# Create a rule per port in var.master_lb_ports
resource "azurerm_lb_rule" "proxy_rule" {
  count                          = "${length(var.proxy_lb_ports)}"
  resource_group_name            = "${local.rg_name}"
  loadbalancer_id                = "${azurerm_lb.controlplane.id}"
  name                           = "Proxyport${element(var.proxy_lb_ports, count.index)}"
  protocol                       = "Tcp"
  frontend_port                  = "${element(var.proxy_lb_ports, count.index)}"
  backend_port                   = "${element(var.proxy_lb_ports, count.index)}"
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
