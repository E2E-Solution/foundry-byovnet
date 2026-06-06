variable "subscription_id" {
  type        = string
  description = "Azure subscription ID where Foundry will be provisioned."
}

variable "location" {
  type        = string
  description = "Azure location where resources will be provisioned."
}

variable "pep_vnet_name" {
  type        = string
  description = "Name of the VNet of private endpoints subnet."
}

variable "pep_subnet_name" {
  type        = string
  description = "Name of the private endpoint subnet in the VNet."
}

variable "agent_svc_vnet_name" {
  type        = string
  description = "Name of the VNet of agent services subnet."
}

variable "agent_svc_subnet_name" {
  type        = string
  description = "Name of the agent services subnet in the VNet."
}

variable "foundry_rg_name" {
  type        = string
  description = "Name of the new resource group that will hold the Foundry + BYOR resources."
}

variable "base_name" {
  type        = string
  description = "Short suffix used by the naming module."
  default     = "byor"
}

variable "pep_vnet_subnet_cidrs" {
  description = "CIDR ranges for the subnets in the private endpoints VNet."
  type = object({
    private_endpoints = string
    bastion           = string
    vm                = string
  })
}

variable "agent_vnet_subnet_cidrs" {
  description = "CIDR ranges for the subnets in the agent services VNet."
  type = object({
    agent_services = string
  })
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to created resources."
  default = {
    environment     = "test"
    workload        = "ai-foundry-byor"
    SecurityControl = "Ignore"
  }
}
