output "resource_group_name" {
  value     = azurerm_resource_group.main.name
}

output "location" {
    value = "${var.location}"
}

output "storage_account_name" {
  value = azurerm_storage_account.my_storage_account.name
}

output "storage_blob_endpoint" {
  value = azurerm_storage_account.my_storage_account.primary_blob_endpoint
}

output "private_endpoint_ip" {
  value = azurerm_private_endpoint.my_private_endpoint.private_service_connection[0].private_ip_address
}
