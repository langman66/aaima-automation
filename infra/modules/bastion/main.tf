variable "rg_name" {}
variable "location" {}
variable "bastion_subnet_id" {}

resource "azurerm_public_ip" "bastion" {
  name                = "pip-${var.location}-aaimadev-bastion"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-aaimadev"
  location            = var.location
  resource_group_name = var.rg_name

  sku                    = "Standard"  
  tunneling_enabled      = false
  ip_connect_enabled     = false
  file_copy_enabled      = false
  copy_paste_enabled     = true

  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.bastion_subnet_id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}
