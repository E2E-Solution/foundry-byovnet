output "resource_group_name" {
  description = "Name of the Foundry resource group."
  value       = azurerm_resource_group.foundry.name
}

output "foundry_account_id" {
  description = "Resource ID of the AI Foundry (Cognitive Services) account."
  value       = try(module.ai_foundry.ai_foundry.id, null)
}

output "foundry_endpoint" {
  description = "Endpoint of the AI Foundry account."
  value       = try(module.ai_foundry.ai_foundry.endpoint, null)
}

output "ai_foundry_module" {
  description = "Full output of the AI Foundry pattern module (projects, connections, etc.)."
  value       = module.ai_foundry
}

output "bastion_id" {
  description = "Resource ID of the Bastion host."
  value       = module.bastion_host.resource_id
}

output "vm_id" {
  description = "Resource ID of the jumpbox VM."
  value       = module.virtual_machine.resource_id
}

output "vm_admin_username" {
  description = "Admin username for the jumpbox VM."
  value       = "azureadmin"
}

output "vm_admin_password" {
  description = "Generated admin password for the jumpbox VM."
  value       = random_password.vm.result
  sensitive   = true
}
