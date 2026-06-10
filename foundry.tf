# Cooldown to allow agent subnet to settle before destroy-time purge.
resource "time_sleep" "purge_ai_foundry_cooldown" {
  destroy_duration = "900s"

  depends_on = [azurerm_subnet.agent_services]
}

# Destroy-time action: purge the soft-deleted Cognitive Services account so the
# service association link on the agent subnet is released.
resource "azapi_resource_action" "purge_ai_foundry" {
  type        = "Microsoft.CognitiveServices/locations/resourceGroups/deletedAccounts@2025-09-01"
  resource_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.CognitiveServices/locations/${azurerm_resource_group.foundry.location}/resourceGroups/${azurerm_resource_group.foundry.name}/deletedAccounts/${module.naming.cognitive_account.name_unique}"

  method = "DELETE"
  when   = "destroy"

  depends_on = [time_sleep.purge_ai_foundry_cooldown]
}

module "ai_foundry" {
  source  = "Azure/avm-ptn-aiml-ai-foundry/azurerm"
  version = "0.11.0"

  base_name                  = var.base_name
  location                   = azurerm_resource_group.foundry.location
  resource_group_resource_id = azurerm_resource_group.foundry.id

  create_byor                         = false
  create_private_endpoints            = true
  private_endpoint_subnet_resource_id = azurerm_subnet.private_endpoints.id

  ai_foundry = {
    create_ai_agent_service       = true
    name                          = module.naming.cognitive_account.name_unique
    public_network_access_enabled = false
    private_dns_zone_resource_ids = [
      azurerm_private_dns_zone.this["openai"].id,
      azurerm_private_dns_zone.this["cognitiveservices"].id,
      azurerm_private_dns_zone.this["ai_services"].id,
    ]
    # Standard Agent Setup: inject agent compute into a delegated customer subnet.
    # WARNING — prerequisite not yet met:
    # The AI Agent platform rejects any VNet whose address space overlaps the
    # reserved 10.0.0.0/8 range. `alpha-azvm-vnet` currently has BOTH
    # 10.1.0.0/16 and 172.16.0.0/16 prefixes, so applying this change will fail
    # at the account-level capabilityHost (`<account>@aml_aiagentservice`) create
    # with `NetworkRangeOverlapError`, same as a prior attempt.
    # Resolution: remove the 10.1.0.0/16 prefix from `alpha-azvm-vnet` (requires
    # re-addressing the snet-private-endpoints / AzureBastionSubnet / snet-vm
    # subnets into 172.16.x.x first), OR move the delegated subnet into a
    # separate dedicated VNet with no 10.x overlap (peer for DNS/connectivity).
    network_injections = [{
      scenario                   = "agent"
      subnetArmId                = azurerm_subnet.agent_services.id
      useMicrosoftManagedNetwork = false
    }]
  }

  ai_model_deployments = {
    "gpt-4o" = {
      name = "gpt-4.1"
      model = {
        format  = "OpenAI"
        name    = "gpt-4.1"
        version = "2025-04-14"
      }
      scale = {
        type     = "GlobalStandard"
        capacity = 1
      }
    }
  }

  ai_projects = {
    project_1 = {
      name                       = "project-1"
      description                = "Project 1 description"
      display_name               = "Project 1 Display Name"
      create_project_connections = true
      cosmos_db_connection = {
        new_resource_map_key = "this"
        existing_resource_id = module.cosmosdb.resource_id
      }
      ai_search_connection = {
        new_resource_map_key = "this"
        existing_resource_id = azapi_resource.ai_search.id
      }
      storage_account_connection = {
        new_resource_map_key = "this"
        existing_resource_id = module.storage_account.resource_id
      }
    }
  }

  ai_search_definition = {
    this = {
      existing_resource_id = azapi_resource.ai_search.id
      diagnostic_settings = {
        to_law = {
          name                  = "diag-to-law"
          workspace_resource_id = azurerm_log_analytics_workspace.this.id
          log_groups            = ["allLogs"]
          metric_categories     = ["AllMetrics"]
        }
      }
    }
  }

  cosmosdb_definition = {
    this = {
      existing_resource_id = module.cosmosdb.resource_id
      diagnostic_settings = {
        to_law = {
          name                  = "diag-to-law"
          workspace_resource_id = azurerm_log_analytics_workspace.this.id
          log_groups            = ["allLogs"]
          metric_categories     = ["AllMetrics"]
        }
      }
    }
  }

  key_vault_definition = {
    this = {
      existing_resource_id = module.key_vault.resource_id
      diagnostic_settings = {
        to_law = {
          name                  = "diag-to-law"
          workspace_resource_id = azurerm_log_analytics_workspace.this.id
          log_groups            = ["allLogs"]
          metric_categories     = ["AllMetrics"]
        }
      }
    }
  }

  storage_account_definition = {
    this = {
      existing_resource_id = module.storage_account.resource_id
      diagnostic_settings_storage_account = {
        to_law = {
          name                  = "diag-to-law"
          workspace_resource_id = azurerm_log_analytics_workspace.this.id
          metric_categories     = ["AllMetrics"]
        }
      }
    }
  }

  tags = var.tags

  depends_on = [azapi_resource_action.purge_ai_foundry]
}

# Workaround for Azure/avm-ptn-aiml-ai-foundry v0.11.0: when network_injections
# is set, the module skips creating the account-level capabilityHost. Azure
# still requires it before any project-level capabilityHost can be created.
# See: project capabilityHost PUT returns 400 "Foundry Account capabilityHost
# Not Found" without it.
resource "azapi_resource" "account_capability_host" {
  type      = "Microsoft.CognitiveServices/accounts/capabilityHosts@2025-04-01-preview"
  name      = "ai-agent-service"
  parent_id = module.ai_foundry.ai_foundry_id

  body = {
    properties = {
      capabilityHostKind = "Agents"
      customerSubnet     = azurerm_subnet.agent_services.id
    }
  }

  schema_validation_enabled = false
}
