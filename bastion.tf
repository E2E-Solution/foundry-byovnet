resource "azurerm_public_ip" "bastion" {
  name                = module.naming.public_ip.name_unique
  location            = azurerm_resource_group.foundry.location
  resource_group_name = azurerm_resource_group.foundry.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = null # EDITED SEA doesnt support availability zones, so we set this to null to avoid errors
  tags                = var.tags
}

module "bastion_host" {
  source  = "Azure/avm-res-network-bastionhost/azurerm"
  version = "0.8.0"

  name                = module.naming.bastion_host.name_unique
  location            = azurerm_resource_group.foundry.location
  resource_group_name = azurerm_resource_group.foundry.name

  ip_configuration = {
    name                 = "default-ipconfig"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
    create_public_ip     = false
  }

  scale_units            = 2
  shareable_link_enabled = true
  sku                    = "Standard"
  zones                  = [] # EDITED SEA doesnt support availability zones, so we set this to empty to avoid errors
}
