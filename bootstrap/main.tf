terraform {
  required_version = ">= 1.8.5"
  required_providers { azurerm = { source = "hashicorp/azurerm", version = ">= 3.110.0" } }
}
provider "azurerm" { features {} subscription_id = "be919d3c-e0c6-4f3a-87f3-826d529e6788" }

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-aaima-tfstate-wus2"
  location = "westus2"
}

resource "azurerm_storage_account" "tfstate" {
  name                     = "aaimatfstatewus2"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = "westus2"
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  allow_nested_items_to_be_public = false
  min_tls_version          = "TLS1_2"
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}
