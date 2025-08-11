terraform {
    required_version = ">= 1.5.0"
    required_providers {
        azurerm = {
            source = "hashicorp/aruerm"
            version = "~> 3.50"
        }
    }
}

provider "azurerm" {
    features{}
}

resource "azurerm_resource_group" "main" {
  name = "${var.project_name}-rg"
  location = var.location
}

