terraform {
  required_version = ">= 1.6, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  # Configure a separate private state container/key per environment with Entra RBAC.
  backend "azurerm" {}
}
provider "azurerm" {
  features {}
  # ARM_* OIDC environment variables are supplied by the workflow.
}
module "network" {
  source                  = "../../modules/azure-network"
  name                    = "platform-lab"
  location                = "centralindia"
  address_space           = ["10.80.0.0/16"]
  integration_subnet_cidr = "10.80.1.0/26"
  tags = {
    owner       = "platform-team"
    environment = "lab"
    cost_center = "training"
  }
}
