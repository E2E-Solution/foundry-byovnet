resource "random_password" "vm" {
  length      = 24
  special     = true
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
}

module "virtual_machine" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "0.19.3"

  location            = azurerm_resource_group.foundry.location
  name                = module.naming.virtual_machine.name_unique
  resource_group_name = azurerm_resource_group.foundry.name
  zone                = "1"

  admin_username                                         = "azureadmin"
  admin_password                                         = random_password.vm.result
  disable_password_authentication                        = false
  bypass_platform_safety_checks_on_user_schedule_enabled = false
  patch_assessment_mode                                  = "AutomaticByPlatform"
  patch_mode                                             = "AutomaticByPlatform"
  sku_size                                               = "Standard_D4s_v3"

  network_interfaces = {
    network_interface_1 = {
      name = "${module.naming.network_interface.name_unique}-vm"
      ip_configurations = {
        ip_configuration_1 = {
          name                          = "internal"
          private_ip_subnet_resource_id = azurerm_subnet.vm.id
        }
      }
    }
  }

  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  tags = var.tags
}
