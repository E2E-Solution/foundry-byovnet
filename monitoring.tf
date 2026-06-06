resource "azurerm_log_analytics_workspace" "this" {
  name                = module.naming.log_analytics_workspace.name_unique
  location            = azurerm_resource_group.foundry.location
  resource_group_name = azurerm_resource_group.foundry.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
  tags                = var.tags
}
