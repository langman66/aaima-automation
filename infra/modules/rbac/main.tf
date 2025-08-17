variable "principal_id" {}
variable "role_definition_name" {}
variable "scope_resource_id" {}

data "azurerm_role_definition" "role" {
  name = var.role_definition_name
  scope = var.scope_resource_id
}

resource "azurerm_role_assignment" "ra" {
  scope              = var.scope_resource_id
  role_definition_id = data.azurerm_role_definition.role.role_definition_id
  principal_id       = var.principal_id
}
