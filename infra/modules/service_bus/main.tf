variable "name_prefix" {}
variable "location" {}
variable "rg_name" {}
variable "vnet_id" {}
variable "sb_pe_subnet_id" {}
variable "private_dns_zone_id" {}
variable "log_analytics_id" {}
variable "tags" { type = map(string) }

resource "azurerm_servicebus_namespace" "ns" {
  name                          = "sb-${var.name_prefix}-wus2"
  location                      = var.location
  resource_group_name           = var.rg_name
  sku                           = "Premium"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_servicebus_queue" "q" {
  name               = "q-${var.name_prefix}-requests"
  namespace_id       = azurerm_servicebus_namespace.ns.id
  max_delivery_count = 10
}

resource "azurerm_private_endpoint" "sb" {
  name                = "pe-${var.name_prefix}-sb"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.sb_pe_subnet_id

  private_service_connection {
    name                           = "sb-privatelink"
    private_connection_resource_id = azurerm_servicebus_namespace.ns.id
    subresource_names              = ["namespace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}

resource "azurerm_monitor_diagnostic_setting" "sb_diag" {
  name                       = "diag-sb"
  target_resource_id         = azurerm_servicebus_namespace.ns.id
  log_analytics_workspace_id = var.log_analytics_id
  metric {
    category = "AllMetrics"
    enabled  = true
  }
  enabled_log {
    category = "OperationalLogs"
  }
}

output "queue_id"       { value = azurerm_servicebus_queue.q.id }
output "namespace_fqdn" { value = azurerm_servicebus_namespace.ns.endpoint }
