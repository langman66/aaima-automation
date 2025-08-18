variable "name_prefix" {}
variable "location" {}
variable "rg_name" {}
variable "vnet_id" {}
variable "func_integ_subnet_id" {}
variable "func_pe_subnet_id" {}
variable "private_dns_zone_id_sites" {}
variable "storage_dns_zone_ids" { type = map(string) }
variable "log_analytics_id" {}
variable "tags" { type = map(string) }

locals {
  common_tags = merge(var.tags, { "skip-CloudGov-StoragAcc-SS" = "true" })
}

resource "azurerm_storage_account" "st" {
  name                             = "st${var.name_prefix}funcwus2"
  resource_group_name              = var.rg_name
  location                         = var.location
  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  allow_nested_items_to_be_public  = false
  public_network_access_enabled    = false
  tags                             = local.common_tags
}

resource "azurerm_private_endpoint" "st_blob" {
  name                = "pe-${var.name_prefix}-st-blob"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.func_pe_subnet_id
  private_service_connection {
    name                           = "blob"
    private_connection_resource_id = azurerm_storage_account.st.id
    subresource_names              = ["blob"]
    is_manual_connection           = false    
  }
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.storage_dns_zone_ids["blob"]]
  }
}

resource "azurerm_private_endpoint" "st_queue" {
  name                = "pe-${var.name_prefix}-st-queue"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.func_pe_subnet_id
  private_service_connection {
    name                           = "queue"
    private_connection_resource_id = azurerm_storage_account.st.id
    subresource_names              = ["queue"]
    is_manual_connection           = false    
  }
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.storage_dns_zone_ids["queue"]]
  }
}

resource "azurerm_service_plan" "plan" {
  name                = "plan-${var.name_prefix}-func-wus2"
  resource_group_name = var.rg_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "EP1"
  tags                = var.tags
}

resource "azurerm_linux_function_app" "func" {
  name                       = "func-${var.name_prefix}-wus2"
  resource_group_name        = var.rg_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.st.name
  storage_account_access_key = azurerm_storage_account.st.primary_access_key
  public_network_access_enabled = false
  https_only                 = true

  identity { type = "SystemAssigned" }

  site_config {
    application_stack { 
      node_version = "18" 
    }
    vnet_route_all_enabled = true
  }

  virtual_network_subnet_id = var.func_integ_subnet_id

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    "SERVICEBUS_NAMESPACE"     = "sb-${var.name_prefix}-wus2.servicebus.windows.net"
  }

  depends_on = [
    azurerm_private_endpoint.st_blob,
    azurerm_private_endpoint.st_queue
  ]
  tags = var.tags
}

resource "azurerm_private_endpoint" "func_inbound" {
  name                = "pe-${var.name_prefix}-func-in"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.func_pe_subnet_id
  private_service_connection {
    name                           = "sites"
    private_connection_resource_id = azurerm_linux_function_app.func.id
    subresource_names              = ["sites"]
    is_manual_connection           = false    
  }
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_id_sites]
  }
}

resource "azurerm_monitor_diagnostic_setting" "func_diag" {
  name                       = "diag-func"
  target_resource_id         = azurerm_linux_function_app.func.id
  log_analytics_workspace_id = var.log_analytics_id
  enabled_metric {
    category = "AllMetrics"
  }
  enabled_log { category = "FunctionAppLogs" }
}

output "default_hostname"      { value = azurerm_linux_function_app.func.default_hostname }
output "identity_principal_id" { value = azurerm_linux_function_app.func.identity[0].principal_id }
