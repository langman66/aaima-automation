variable "name_prefix" {}
variable "location" {}
variable "hub_rg_name" {}
variable "hub_vnet_id" {}
variable "spoke_ids" { type = list(string) }
variable "tags" { type = map(string) }

data "azurerm_resource_group" "hub" { name = var.hub_rg_name }

resource "azurerm_private_dns_zone" "web" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = data.azurerm_resource_group.hub.name
}

resource "azurerm_private_dns_zone" "sb" {
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = data.azurerm_resource_group.hub.name
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_resource_group.hub.name
}

resource "azurerm_private_dns_zone" "queue" {
  name                = "privatelink.queue.core.windows.net"
  resource_group_name = data.azurerm_resource_group.hub.name
}

# Links to hub
resource "azurerm_private_dns_zone_virtual_network_link" "hub_links" {
  for_each = {
    web   = azurerm_private_dns_zone.web.id
    sb    = azurerm_private_dns_zone.sb.id
    blob  = azurerm_private_dns_zone.blob.id
    queue = azurerm_private_dns_zone.queue.id
  }
  name                  = "lnk-${each.key}-hub"
  private_dns_zone_name = element(split("/", each.value), length(split("/", each.value)) - 1)
  resource_group_name   = data.azurerm_resource_group.hub.name
  virtual_network_id    = var.hub_vnet_id
  registration_enabled  = false
}

# Links to spokes
resource "azurerm_private_dns_zone_virtual_network_link" "spoke_links" {
  for_each = { for idx, vnet in var.spoke_ids : idx => vnet }
  name                  = "lnk-spoke-${each.key}"
  private_dns_zone_name = azurerm_private_dns_zone.web.name
  resource_group_name   = data.azurerm_resource_group.hub.name
  virtual_network_id    = each.value
  registration_enabled  = false
}

# Repeat links for other zones to spokes
resource "azurerm_private_dns_zone_virtual_network_link" "spoke_links_sb" {
  for_each = { for idx, vnet in var.spoke_ids : idx => vnet }
  name                  = "lnk-sb-spoke-${each.key}"
  private_dns_zone_name = azurerm_private_dns_zone.sb.name
  resource_group_name   = data.azurerm_resource_group.hub.name
  virtual_network_id    = each.value
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke_links_blob" {
  for_each = { for idx, vnet in var.spoke_ids : idx => vnet }
  name                  = "lnk-blob-spoke-${each.key}"
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  resource_group_name   = data.azurerm_resource_group.hub.name
  virtual_network_id    = each.value
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke_links_queue" {
  for_each = { for idx, vnet in var.spoke_ids : idx => vnet }
  name                  = "lnk-queue-spoke-${each.key}"
  private_dns_zone_name = azurerm_private_dns_zone.queue.name
  resource_group_name   = data.azurerm_resource_group.hub.name
  virtual_network_id    = each.value
  registration_enabled  = false
}

output "zones" {
  value = {
    websites   = azurerm_private_dns_zone.web.id
    servicebus = azurerm_private_dns_zone.sb.id
    blob       = azurerm_private_dns_zone.blob.id
    queue      = azurerm_private_dns_zone.queue.id
  }
}
