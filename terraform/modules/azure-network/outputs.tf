output "integration_subnet_id" {
  description = "Subnet ID for App Service regional VNet integration."
  value       = azurerm_subnet.app_service.id
}
