variable "name_prefix" {}
variable "rg_name" {}
variable "location" {}
variable "vnet_id" {}
variable "pe_subnet_id" {}
variable "kv_id" {}
variable "private_dns_zone_id_vault" {
  description = "ID of the existing privatelink.vaultcore.azure.net zone"
  type        = string
}

# data "azurerm_resource_group" "hub" { name = var.rg_name }

# resource "azurerm_private_dns_zone" "vaultcore" {
#   name                = "privatelink.vaultcore.azure.net"
#   resource_group_name = var.rg_name
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "vaultcore_link" {
#   name                  = "lnk-vaultcore-hub"
#   resource_group_name   = var.rg_name
#   private_dns_zone_name = azurerm_private_dns_zone.vaultcore.name
#   virtual_network_id    = var.vnet_id
#   registration_enabled  = false
# }

resource "azurerm_private_endpoint" "kv_pe" {
  name                = "pe-${var.name_prefix}-kv"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.pe_subnet_id
  private_service_connection {
    name                           = "kv-privatelink"
    private_connection_resource_id = var.kv_id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "default"
    #private_dns_zone_ids = [azurerm_private_dns_zone.vaultcore.id]
    private_dns_zone_ids = [var.private_dns_zone_id_vault]
  }
}

data "azurerm_client_config" "current" {}

# Self-signed certificate for AppGW (to be replaced later)
resource "azurerm_key_vault_certificate" "self_signed" {
  name         = "agw-temp-cert"
  key_vault_id = var.kv_id

  // ensure PE + DNS exist first (won’t fix off‑VNet access, but correct ordering)
#   Option A — Run Terraform from inside the VNet

# Use a self-hosted runner or VM in the hub VNet.
# Confirm DNS resolves your vault to a private IP:
# nslookup kv-<prefix>-wus2.vault.azure.net returns a privatelink IP.
# Then re-apply; the existing code will work.
# Option B — Defer certificate creation when running outside the VNet Add a toggle and dependency to the module:
  // ensure PE exists before attempting data-plane calls
  # depends_on = [
  #   azurerm_private_endpoint.kv_pe,
  #   azurerm_private_dns_zone_virtual_network_link.vaultcore_link
  # ]
  depends_on = [azurerm_private_endpoint.kv_pe]

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }
      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      subject            = "CN=aaimadev.local"
      validity_in_months = 12
      key_usage          = ["digitalSignature", "keyEncipherment"]
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"] # Server Auth
    }
  }
}

output "self_signed_cert_secret_id" {
  value = azurerm_key_vault_certificate.self_signed.secret_id
}