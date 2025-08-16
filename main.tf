terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.50"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.location
}

#NSG
resource "azurerm_network_security_group" "main" {
  name                = "${var.project_name}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowHttpsOut"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                  = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#VNET
resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

#Subnets
resource "azurerm_subnet" "private_subnet" {
  name                 = "${var.project_name}-private-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet" "webapp_subnet" {
  name = "${var.project_name}-webapp-subnet"
  resource_group_name = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes = ["10.0.2.0/24"]
}

#NSG anbinden
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.private_subnet.id
  network_security_group_id = azurerm_network_security_group.main.id
}

#Storage Account
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "difgh3567fhgt5"
  location                 = azurerm_resource_group.main.location
  resource_group_name      = azurerm_resource_group.main.name
  account_tier             = "Standard"
  account_replication_type = "LRS"

  public_network_access_enabled = false

  network_rules {
    default_action = "Deny"
    bypass         = ["None"]  # auch Azure Services nicht durchlassen
  }
}

#Private Endpoint for Storage Account
resource "azurerm_private_endpoint" "my_private_endpoint"{
  name = "private-endpoint-for-storage"
  location = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id = azurerm_subnet.private_subnet.id

  private_service_connection {
    name = "private-serviceconnection"
    private_connection_resource_id = azurerm_storage_account.my_storage_account.id
    is_manual_connection = false
  }

  private_dns_zone_group {
    name                 = "dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.my_terraform_dns_zone.id]
  }
}

# Create private DNS zone
resource "azurerm_private_dns_zone" "my_terraform_dns_zone" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

# Create virtual network link
resource "azurerm_private_dns_zone_virtual_network_link" "my_terraform_vnet_link" {
  name                  = "vnet-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.my_terraform_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

#App Service Plan
resource "azurerm_service_plan" "webapp_plan" {
  name                = "${var.project_name}-plan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "B1"   # Basic Tier
}

# Linux Web App
resource "azurerm_linux_web_app" "webapp" {
  name                = "${var.project_name}-webapp"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.webapp_plan.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    linux_fx_version = "DOCKER|${azurerm_container_registry.acr.login_server}/mini-blob-writer-python:latest"
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "STORAGE_ACCOUNT_NAME"                = azurerm_storage_account.storage.name
    "CONTAINER_NAME"                      = "inputs"
  }
}

#Vnet Integration
resource "azurerm_app_service_virtual_network_swift_connection" "vnet_integration" {
  app_service_id = azurerm_linux_web_app.webapp.id
  subnet_id      = azurerm_subnet.webapp_subnet.id##
}

#ACR
resource "azurerm_container_registry" "acr" {
  name                = "myacr23456234654"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false  
  #public_network_access_enabled = false 
}

# Role Assignments
resource "azurerm_role_assignment" "webapp_storage" {
  principal_id         = azurerm_linux_web_app.webapp.identity[0].principal_id
  role_definition_name = "Storage Blob Data Contributor"
  scope                = azurerm_storage_account.my_storage_account.id
}

resource "azurerm_role_assignment" "webapp_acr_pull" {
  principal_id         = azurerm_linux_web_app.webapp.identity[0].principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}