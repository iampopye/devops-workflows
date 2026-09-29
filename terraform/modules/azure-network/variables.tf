variable "name" {
  description = "Resource group and network name prefix."
  type        = string
}
variable "location" {
  description = "Azure region selected for residency and service availability."
  type        = string
}
variable "address_space" {
  description = "Non-overlapping VNet CIDRs agreed with the on-prem network team."
  type        = list(string)
}
variable "integration_subnet_cidr" {
  description = "Dedicated App Service integration subnet; plan capacity and scaling headroom."
  type        = string
}
variable "tags" {
  description = "Required ownership, environment and cost tags."
  type        = map(string)
  validation {
    condition     = alltrue([for key in ["owner", "environment", "cost_center"] : contains(keys(var.tags), key)])
    error_message = "Include owner, environment and cost_center tags."
  }
}
