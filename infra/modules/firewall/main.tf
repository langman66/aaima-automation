variable "name_prefix" {}
variable "location" {}
variable "hub_rg_name" {}
variable "hub_vnet_id" {}
variable "firewall_subnet_id" {}
variable "log_analytics_id" {}
variable "tags" { type = map(string) }

data "azurerm_resource_group" "hub" { name = var.hub_rg_name }

resource "azurerm_public_ip" "fw_pip" {
  name                = "pip-${var.name_prefix}-fw-wus2"
  resource_group_name = data.azurerm_resource_group.hub.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy" "policy" {
  name                = "fp-${var.name_prefix}-wus2"
  resource_group_name = data.azurerm_resource_group.hub.name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_firewall" "fw" {
  name                = "afw-${var.name_prefix}-wus2"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.hub.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.policy.id
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.firewall_subnet_id
    public_ip_address_id = azurerm_public_ip.fw_pip.id
  }
}

resource "azurerm_route_table" "egress" {
  name                = "rt-${var.name_prefix}-egress-wus2"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.hub.name
  tags                = var.tags
  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_monitor_diagnostic_setting" "fw_diag" {
  name                       = "diag-afw"
  target_resource_id         = azurerm_firewall.fw.id
  log_analytics_workspace_id = var.log_analytics_id
  enabled_metric {
    category = "AllMetrics"
  }
  enabled_log { category = "AzureFirewallApplicationRule" }
  enabled_log { category = "AzureFirewallNetworkRule" }
  enabled_log { category = "AzureFirewallDNSProxy" }
}

output "private_ip" { value = azurerm_firewall.fw.ip_configuration[0].private_ip_address }
output "egress_rt_id" { value = azurerm_route_table.egress.id }
