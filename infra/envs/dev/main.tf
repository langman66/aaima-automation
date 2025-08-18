terraform {
  required_version = ">= 1.8.5"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 3.110.0" }
    azuread = { source = "hashicorp/azuread", version = ">= 2.52.0" }
    random  = { source = "hashicorp/random", version = ">= 3.6.0" }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  prefix   = var.name_prefix
  location = var.location
  region   = "wus2"
  tags = {
    project   = local.prefix
    env       = var.environment
    region    = local.region
    owner     = "platform",
    ringValue = "r0"
  }
}

module "logs" {
  source      = "../../modules/logs"
  name_prefix = local.prefix
  location    = local.location
  tags        = local.tags
}

module "hub" {
  source           = "../../modules/hub"
  name_prefix      = local.prefix
  location         = local.location
  address_space    = ["10.0.0.0/16"]
  tags             = local.tags
  log_analytics_id = module.logs.law_id
}

module "firewall" {
  source             = "../../modules/firewall"
  name_prefix        = local.prefix
  location           = local.location
  hub_rg_name        = module.hub.rg_name
  hub_vnet_id        = module.hub.vnet_id
  firewall_subnet_id = module.hub.subnets["azure_firewall"]
  log_analytics_id   = module.logs.law_id
  tags               = local.tags
}

module "spoke_app" {
  source          = "../../modules/spoke_app"
  name_prefix     = local.prefix
  location        = local.location
  address_space   = ["10.10.0.0/16"]
  func_integ_cidr = "10.10.1.0/24"
  func_pe_cidr    = "10.10.2.0/24"
  egress_rt_id    = module.firewall.egress_rt_id
  tags            = local.tags
}

module "spoke_msg" {
  source        = "../../modules/spoke_msg"
  name_prefix   = local.prefix
  location      = local.location
  address_space = ["10.20.0.0/16"]
  sb_pe_cidr    = "10.20.1.0/24"
  tags          = local.tags
}

module "peering" {
  source      = "../../modules/peering"
  hub_rg_name = module.hub.rg_name
  hub_vnet_id = module.hub.vnet_id
  spoke_ids   = [module.spoke_app.vnet_id, module.spoke_msg.vnet_id]
}

module "private_dns" {
  source      = "../../modules/private_dns"
  name_prefix = local.prefix
  location    = local.location
  hub_rg_name = module.hub.rg_name
  hub_vnet_id = module.hub.vnet_id
  spoke_ids   = [module.spoke_app.vnet_id, module.spoke_msg.vnet_id]
  tags        = local.tags
}

module "service_bus" {
  source              = "../../modules/service_bus"
  name_prefix         = local.prefix
  location            = local.location
  rg_name             = module.spoke_msg.rg_name
  vnet_id             = module.spoke_msg.vnet_id
  sb_pe_subnet_id     = module.spoke_msg.subnets["sb_pe"]
  private_dns_zone_id = module.private_dns.zones["servicebus"]
  log_analytics_id    = module.logs.law_id
  tags                = local.tags
}

module "function_app" {
  source                    = "../../modules/function_app"
  name_prefix               = local.prefix
  location                  = local.location
  rg_name                   = module.spoke_app.rg_name
  vnet_id                   = module.spoke_app.vnet_id
  func_integ_subnet_id      = module.spoke_app.subnets["func_integ"]
  func_pe_subnet_id         = module.spoke_app.subnets["func_pe"]
  private_dns_zone_id_sites = module.private_dns.zones["websites"]
  storage_dns_zone_ids = {
    blob  = module.private_dns.zones["blob"]
    queue = module.private_dns.zones["queue"]
  }
  log_analytics_id = module.logs.law_id
  tags             = local.tags
}

# module "rbac" {
#   source               = "../../modules/rbac"
#   principal_id         = module.function_app.identity_principal_id
#   role_definition_name = "Azure Service Bus Data Sender"
#   scope_resource_id    = module.service_bus.queue_id
# }

# module "keyvault" {
#   source      = "../../modules/keyvault"
#   name_prefix = local.prefix
#   location    = local.location
#   rg_name     = module.hub.rg_name
#   tags        = local.tags
# }

# module "app_gateway" {
#   source              = "../../modules/app_gateway"
#   name_prefix         = local.prefix
#   location            = local.location
#   rg_name             = module.hub.rg_name
#   appgw_subnet_id     = module.hub.subnets["appgw"]
#   backend_host_fqdn   = module.function_app.default_hostname
#   waf_mode            = "Prevention"
#   key_vault_id        = module.keyvault.kv_id
#   key_vault_secret_id = module.keyvault.self_signed_cert_secret_id
#   log_analytics_id    = module.logs.law_id
#   tags                = local.tags
# }
