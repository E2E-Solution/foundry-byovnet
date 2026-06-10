# ---------------------------------------------------------------------------
# AI Search (azapi) + private endpoint
# ---------------------------------------------------------------------------
resource "azapi_resource" "ai_search" {
  type      = "Microsoft.Search/searchServices@2024-06-01-preview"
  name      = module.naming.search_service.name_unique
  parent_id = azurerm_resource_group.foundry.id
  location  = azurerm_resource_group.foundry.location

  body = {
    sku = {
      name = "standard"
    }
    identity = {
      type = "SystemAssigned"
    }
    properties = {
      replicaCount     = 2
      partitionCount   = 1
      hostingMode      = "default"
      semanticSearch   = "disabled"
      disableLocalAuth = false
      authOptions = {
        aadOrApiKey = {
          aadAuthFailureMode = "http401WithBearerChallenge"
        }
      }
      publicNetworkAccess = "Disabled"
      networkRuleSet = {
        bypass  = "None"
        ipRules = []
      }
    }
  }
  schema_validation_enabled = true
  tags                      = var.tags
}

resource "azurerm_private_endpoint" "pe_aisearch" {
  name                = "${azapi_resource.ai_search.name}-private-endpoint"
  location            = azurerm_resource_group.foundry.location
  resource_group_name = azurerm_resource_group.foundry.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "${azapi_resource.ai_search.name}-private-link-service-connection"
    is_manual_connection           = false
    private_connection_resource_id = azapi_resource.ai_search.id
    subresource_names              = ["searchService"]
  }

  private_dns_zone_group {
    name                 = "${azapi_resource.ai_search.name}-dns-config"
    private_dns_zone_ids = [azurerm_private_dns_zone.this["search"].id]
  }

  depends_on = [
    # module.cosmosdb,
    azapi_resource.ai_search,
  ]

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------
module "key_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "0.10.2"

  name                = module.naming.key_vault.name_unique
  location            = azurerm_resource_group.foundry.location
  resource_group_name = azurerm_resource_group.foundry.name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true

  network_acls = {
    default_action = "Deny"
    bypass         = "None"
  }

  public_network_access_enabled = false

  diagnostic_settings = {
    keyvault = {
      name                  = "sendToLogAnalytics-kv-${module.naming.log_analytics_workspace.name_unique}"
      workspace_resource_id = azurerm_log_analytics_workspace.this.id
    }
  }

  private_endpoints = {
    "vault" = {
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.this["keyvault"].id]
      subnet_resource_id            = azurerm_subnet.private_endpoints.id
      subresource_name              = "vault"
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Storage Account
# ---------------------------------------------------------------------------
module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.6.7"

  name                          = module.naming.storage_account.name_unique
  location                      = azurerm_resource_group.foundry.location
  resource_group_name           = azurerm_resource_group.foundry.name
  access_tier                   = "Hot"
  account_kind                  = "StorageV2"
  account_replication_type      = "ZRS"
  account_tier                  = "Standard"
  https_traffic_only_enabled    = true
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = false
  shared_access_key_enabled     = false

  network_rules = {
    bypass         = ["AzureServices"]
    default_action = "Deny"
    ip_rules       = []
    private_link_access = [{
      endpoint_resource_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Security/datascanners/storageDataScanner"
      endpoint_tenant_id   = data.azurerm_client_config.current.tenant_id
    }]
  }

  #   diagnostic_settings_blob = {
  #     blob = {
  #       name                  = "sendToLogAnalytics-blob-${module.naming.log_analytics_workspace.name_unique}"
  #       workspace_resource_id = azurerm_log_analytics_workspace.this.id
  #       log_categories        = ["audit", "alllogs"]
  #       metric_categories     = ["AllMetrics"]
  #       log_groups = [] # EDITED bug in AVM module where it sets log_groups ["allLogs"] even when log_categories is set, which causes deployment to fail since "allLogs" is not a valid log category for storage accounts. Setting log_groups to null to avoid this issue.
  #     }
  #   }

  #   diagnostic_settings_storage_account = {
  #     storage = {
  #       name                  = "sendToLogAnalytics-storage-${module.naming.log_analytics_workspace.name_unique}"
  #       workspace_resource_id = azurerm_log_analytics_workspace.this.id
  #       metric_categories     = ["AllMetrics"]
  #     }
  #   }

  private_endpoints = {
    "blob" = {
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.this["storage_blob"].id]
      subnet_resource_id            = azurerm_subnet.private_endpoints.id
      subresource_name              = "blob"
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Cosmos DB
# ---------------------------------------------------------------------------
module "cosmosdb" {
  source  = "Azure/avm-res-documentdb-databaseaccount/azurerm"
  version = "0.10.0"

  name                = module.naming.cosmosdb_account.name_unique
  location            = azurerm_resource_group.foundry.location
  resource_group_name = azurerm_resource_group.foundry.name

  analytical_storage_enabled = false # EDITED we disable analytical storage it not able to be enabled during creation of the account.

  capacity = {
    total_throughput_limit = -1
  }

  consistency_policy = {
    consistency_level       = "Session"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100001
  }

  diagnostic_settings = {
    to_law = {
      name                  = "diag"
      workspace_resource_id = azurerm_log_analytics_workspace.this.id
      metric_categories     = ["SLI", "Requests"]
    }
  }

  ip_range_filter = []

  local_authentication_disabled         = true
  multiple_write_locations_enabled      = false
  network_acl_bypass_for_azure_services = false
  partition_merge_enabled               = false
  public_network_access_enabled         = false

  private_endpoints = {
    "cosmosdb" = {
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.this["cosmosdb"].id]
      subnet_resource_id            = azurerm_subnet.private_endpoints.id
      subresource_name              = "sql"
    }
  }

  geo_locations = [{
    zone_redundant    = false
    location          = "southeastasia"
    failover_priority = 0
  }]

  tags = var.tags
}
