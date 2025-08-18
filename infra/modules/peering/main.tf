variable "hub_rg_name" {}
variable "hub_vnet_id" {}
variable "spoke_ids" { type = list(string) }

# Create peering between hub and each spoke (both directions)
locals {
  # Hub info
  hub_name = basename(var.hub_vnet_id)
  hub_rg   = var.hub_rg_name

  # Parse each Spoke VNet ID to get name and RG
  spoke = {
    for id in var.spoke_ids : id => {
      name = basename(id)
      rg   = element(split("/", id), index(split("/", id), "resourceGroups") + 1)
    }
  }
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each                     = toset(var.spoke_ids)
  name                         = "peer-hub-to-${replace(each.value, "/", "-")}"
  resource_group_name          = local.hub_rg
  virtual_network_name         = local.hub_name
  remote_virtual_network_id    = each.value
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each                     = toset(var.spoke_ids)
  name                         = "peer-spoke-to-hub"
  resource_group_name          = local.spoke[each.key].rg
  virtual_network_name         = local.spoke[each.key].name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
}