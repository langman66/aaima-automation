variable "name_prefix" {}
variable "location" {}
variable "rg_name" {}
variable "appgw_subnet_id" {}
variable "backend_host_fqdn" {}
variable "waf_mode" { default = "Prevention" }
variable "key_vault_id" {}
variable "key_vault_secret_id" {}
variable "log_analytics_id" {}
variable "tags" { type = map(string) }

data "azurerm_resource_group" "rg" { name = var.rg_name }

resource "azurerm_public_ip" "pip" {
  name                = "pip-${var.name_prefix}-appgw-wus2"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# User-assigned identity for AppGW to pull cert from Key Vault
resource "azurerm_user_assigned_identity" "agw_id" {
  name                = "uai-${var.name_prefix}-appgw"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = var.tags
}

# RBAC for Key Vault secret get (Key Vault is RBAC-enabled in module)
resource "azurerm_role_assignment" "kv_secret_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.agw_id.principal_id
}

resource "azurerm_application_gateway" "agw" {
  name                = "agw-${var.name_prefix}-wus2"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  sku { 
    name = "WAF_v2" 
    tier = "WAF_v2" 
  }
  
  autoscale_configuration {
    min_capacity = 1
    max_capacity = 2
  }  

  waf_configuration { 
    enabled = true 
    firewall_mode = var.waf_mode 
    rule_set_type = "OWASP" 
    rule_set_version = "3.2" 
  }

  identity { 
    type = "UserAssigned" 
    identity_ids = [azurerm_user_assigned_identity.agw_id.id] 
  }

  gateway_ip_configuration { 
    name = "gwcfg" 
    subnet_id = var.appgw_subnet_id 
  }

  frontend_port { 
    name = "https" 
    port = 443 
  }

  frontend_ip_configuration { 
    name = "public" 
    public_ip_address_id = azurerm_public_ip.pip.id 
  }

  ssl_certificate { 
    name = "cert" 
    key_vault_secret_id = var.key_vault_secret_id 
  }

  backend_http_settings {
    name = "bhs"
    protocol = "Https"
    port = 443
    pick_host_name_from_backend_address = true
    request_timeout = 30
    cookie_based_affinity = "Disabled"
  }

  probe {
    name = "func-probe"
    protocol = "Https"
    path = "/api/health"
    interval = 30
    timeout = 30
    unhealthy_threshold = 3
    pick_host_name_from_backend_http_settings = true
  }

  backend_address_pool { 
    name = "pool" 
    fqdns = [var.backend_host_fqdn] 
  }

  http_listener {
    name = "listener-443"
    frontend_ip_configuration_name = "public"
    frontend_port_name = "https"
    protocol = "Https"
    ssl_certificate_name = "cert"
  }

  request_routing_rule {
    name = "rule1"
    rule_type = "Basic"
    http_listener_name = "listener-443"
    backend_address_pool_name = "pool"
    backend_http_settings_name = "bhs"
    #probe_name = "func-probe"
  }
  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "agw_diag" {
  name                       = "diag-appgw"
  target_resource_id         = azurerm_application_gateway.agw.id
  log_analytics_workspace_id = var.log_analytics_id
  enabled_metric {
    category = "AllMetrics"
  }
  enabled_log { category = "ApplicationGatewayAccessLog" }
  enabled_log { category = "ApplicationGatewayFirewallLog" }
  enabled_log { category = "ApplicationGatewayPerformanceLog" }
}

output "public_ip_fqdn" { value = azurerm_public_ip.pip.fqdn }
