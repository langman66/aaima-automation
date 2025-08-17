variable "name_prefix" {}
variable "location" {}
variable "address_space" { type = list(string) }
variable "sb_pe_cidr" {}
variable "tags" { type = map(string) }

resource "azurerm_resource_group" "spoke" {
  name     = "rg-${var.name_prefix}-msg-wus2"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.name_prefix}-msg-wus2"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_subnet" "sb_pe" {
  name                 = "snet-sb-pe"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.sb_pe_cidr]
  private_endpoint_network_policies_enabled = false
}

output "rg_name" { value = azurerm_resource_group.spoke.name }
output "vnet_id" { value = azurerm_virtual_network.spoke.id }
output "subnets" {
  value = {
    sb_pe = azurerm_subnet.sb_pe.id
  }
}
