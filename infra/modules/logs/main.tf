variable "name_prefix" {}
variable "location" {}
variable "tags" { type = map(string) }

resource "azurerm_resource_group" "logs" {
  name     = "rg-${var.name_prefix}-logs-wus2"
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.name_prefix}-wus2"
  location            = var.location
  resource_group_name = azurerm_resource_group.logs.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

output "rg_name" { value = azurerm_resource_group.logs.name }
output "law_id"  { value = azurerm_log_analytics_workspace.law.id }
