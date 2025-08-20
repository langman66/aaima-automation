variable "rg_name" {}
variable "location" {}
variable "mgmt_subnet_id" {}
variable "ssh_public_key_path" {}

resource "azurerm_network_interface" "jumpbox_nic" {
  name                = "nic-aaimadev-jumpbox"
  location            = var.location
  resource_group_name = var.rg_name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.mgmt_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                = "vm-aaimadev-jumpbox"
  location            = var.location
  resource_group_name = var.rg_name
  size                = "Standard_B2s"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.jumpbox_nic.id]
  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_public_key_path)
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  custom_data = filebase64("${path.module}/cloud-init.yml")
}
