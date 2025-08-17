variable "hub_rg_name" {}
variable "hub_vnet_id" {}
variable "spoke_ids" { type = list(string) }

data "azurerm_virtual_network" "hub" { id = var.hub_vnet_id }

# Create peering between hub and each spoke (both directions)
locals { hub_name = data.azurerm_virtual_network.hub.name, hub_rg = var.hub_rg_name }

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each                  = toset(var.spoke_ids)
  name                      = "peer-hub-to-${replace(each.value, "/", "-")}"
  resource_group_name       = local.hub_rg
  virtual_network_name      = local.hub_name
  remote_virtual_network_id = each.value
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each                  = toset(var.spoke_ids)
  name                      = "peer-spoke-to-hub"
  resource_group_name       = data.azurerm_virtual_network.spoke[each.key].resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id = var.hub_vnet_id
  allow_forwarded_traffic   = true
  allow_virtual_network_access = true
}

# Datasource for each spoke
data "azurerm_virtual_network" "spoke" {
  for_each = toset(var.spoke_ids)
  id = each.value
}
