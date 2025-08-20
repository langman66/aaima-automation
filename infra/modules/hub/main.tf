variable "name_prefix" {}
variable "location" {}
variable "address_space" { type = list(string) }
variable "tags" { type = map(string) }
variable "log_analytics_id" {}

resource "azurerm_resource_group" "hub" {
  name     = "rg-${var.name_prefix}-hub-wus2"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name_prefix}-hub-wus2"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "appgw" {
  name                 = "AppGwSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "kv_pe" {
  name                  = "snet-kv-pe"
  resource_group_name   = azurerm_resource_group.hub.name
  virtual_network_name  = azurerm_virtual_network.hub.name
  address_prefixes      = ["10.0.2.0/24"]
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.3.0/27"]
}

resource "azurerm_subnet" "mgmt" {
  name                 = "Mgmt"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.10.0/24"]
}


output "rg_name" { value = azurerm_resource_group.hub.name }
output "vnet_id" { value = azurerm_virtual_network.hub.id }
output "subnets" {
  value = {
    appgw         = azurerm_subnet.appgw.id
    azure_firewall= azurerm_subnet.firewall.id
    kv_pe         = azurerm_subnet.kv_pe.id
    bastion        = azurerm_subnet.bastion.id
    mgmt           = azurerm_subnet.mgmt.id
  }
}
