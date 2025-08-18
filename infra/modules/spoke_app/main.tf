variable "name_prefix" {}
variable "location" {}
variable "address_space" { type = list(string) }
variable "func_integ_cidr" {}
variable "func_pe_cidr" {}
variable "egress_rt_id" {}
variable "tags" { type = map(string) }

resource "azurerm_resource_group" "spoke" {
  name     = "rg-${var.name_prefix}-app-wus2"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.name_prefix}-app-wus2"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "func_integ" {
  name                 = "snet-func-integ"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.func_integ_cidr]
  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "func_pe" {
  name                 = "snet-func-pe"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.func_pe_cidr]
  private_endpoint_network_policies = "Disabled" // replaces *_enabled = false
}

resource "azurerm_subnet_route_table_association" "assoc" {
  subnet_id      = azurerm_subnet.func_integ.id
  route_table_id = var.egress_rt_id
}

output "rg_name" { value = azurerm_resource_group.spoke.name }
output "vnet_id" { value = azurerm_virtual_network.spoke.id }
output "subnets" {
  value = {
    func_integ = azurerm_subnet.func_integ.id
    func_pe    = azurerm_subnet.func_pe.id
  }
}
