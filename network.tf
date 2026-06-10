data "azurerm_client_config" "current" {}

# New resource group for the Foundry + BYOR resources.
resource "azurerm_resource_group" "foundry" {
  name     = var.foundry_rg_name
  location = var.location
  tags     = var.tags
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"

  suffix        = [var.base_name]
  unique-length = 5
}

# ---------------------------------------------------------------------------
# Subnets — created inside the existing VNet (in alpha-azvm-rg).
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "pep_vnet" {
  name                = var.pep_vnet_name
  resource_group_name = azurerm_resource_group.foundry.name
  location            = azurerm_resource_group.foundry.location

  address_space = ["10.2.0.0/16"]
}

resource "azurerm_virtual_network" "agent_services_vnet" {
  name                = var.agent_svc_vnet_name
  resource_group_name = azurerm_resource_group.foundry.name
  location            = azurerm_resource_group.foundry.location

  address_space = ["172.17.0.0/16"]
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.foundry.name
  virtual_network_name = azurerm_virtual_network.pep_vnet.name
  address_prefixes     = [var.pep_vnet_subnet_cidrs.private_endpoints]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.foundry.name
  virtual_network_name = azurerm_virtual_network.pep_vnet.name
  address_prefixes     = [var.pep_vnet_subnet_cidrs.bastion]
}

resource "azurerm_subnet" "vm" {
  name                 = "snet-vm"
  resource_group_name  = azurerm_resource_group.foundry.name
  virtual_network_name = azurerm_virtual_network.pep_vnet.name
  address_prefixes     = [var.pep_vnet_subnet_cidrs.vm]
}

resource "azurerm_subnet" "agent_services" {
  name                 = "snet-agent-services"
  resource_group_name  = azurerm_resource_group.foundry.name
  virtual_network_name = azurerm_virtual_network.agent_services_vnet.name
  address_prefixes     = [var.agent_vnet_subnet_cidrs.agent_services]

  delegation {
    name = "Microsoft.App.environments"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ---------------------------------------------------------------------------
# VNet connectivity between agent runtime and private endpoints.
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network_peering" "pep_to_agent_services" {
  name                      = "peer-${azurerm_virtual_network.pep_vnet.name}-to-${azurerm_virtual_network.agent_services_vnet.name}"
  resource_group_name       = azurerm_resource_group.foundry.name
  virtual_network_name      = azurerm_virtual_network.pep_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.agent_services_vnet.id
}

resource "azurerm_virtual_network_peering" "agent_services_to_pep" {
  name                      = "peer-${azurerm_virtual_network.agent_services_vnet.name}-to-${azurerm_virtual_network.pep_vnet.name}"
  resource_group_name       = azurerm_resource_group.foundry.name
  virtual_network_name      = azurerm_virtual_network.agent_services_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.pep_vnet.id
}

# ---------------------------------------------------------------------------
# Private DNS zones (in the Foundry RG) + links to both VNets.
# ---------------------------------------------------------------------------

locals {
  private_dns_zones = {
    storage_blob      = "privatelink.blob.core.windows.net"
    storage_file      = "privatelink.file.core.windows.net"
    keyvault          = "privatelink.vaultcore.azure.net"
    cosmosdb          = "privatelink.documents.azure.com"
    search            = "privatelink.search.windows.net"
    openai            = "privatelink.openai.azure.com"
    cognitiveservices = "privatelink.cognitiveservices.azure.com"
    ai_services       = "privatelink.services.ai.azure.com"
  }
}

resource "azurerm_private_dns_zone" "this" {
  for_each = local.private_dns_zones

  name                = each.value
  resource_group_name = azurerm_resource_group.foundry.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = local.private_dns_zones

  name                  = "vnet-link-${each.key}"
  resource_group_name   = azurerm_resource_group.foundry.name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.key].name
  virtual_network_id    = azurerm_virtual_network.pep_vnet.id
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "agent_services" {
  for_each = local.private_dns_zones

  name                  = "agent-vnet-link-${each.key}"
  resource_group_name   = azurerm_resource_group.foundry.name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.key].name
  virtual_network_id    = azurerm_virtual_network.agent_services_vnet.id
  tags                  = var.tags
}
