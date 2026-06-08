terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 1. Resource Group
resource "azurerm_resource_group" "rg_ventas" {
  name     = "rg-ventas-5756067"
  location = "brazilsouth"
}

# 2. Storage Account (Data Lake Gen 2)
resource "azurerm_storage_account" "sa_ventas" {
  name                     = "saventas5756067"
  resource_group_name      = azurerm_resource_group.rg_ventas.name
  location                 = azurerm_resource_group.rg_ventas.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
}

# Contenedores para la Arquitectura Medallón
resource "azurerm_storage_data_lake_gen2_filesystem" "bronze" {
  name               = "bronze"
  storage_account_id = azurerm_storage_account.sa_ventas.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "silver" {
  name               = "silver"
  storage_account_id = azurerm_storage_account.sa_ventas.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "gold" {
  name               = "gold"
  storage_account_id = azurerm_storage_account.sa_ventas.id
}

# 3. Azure SQL Database (Para el modelo de Data Warehouse final)
resource "azurerm_mssql_server" "sql_server_ventas" {
  name                         = "sql-server-ventas-5756067"
  resource_group_name          = azurerm_resource_group.rg_ventas.name
  location                     = azurerm_resource_group.rg_ventas.location
  version                      = "12.0"
  administrator_login          = "adminventas"
  administrator_login_password = "Password1234!" # Cambiar en producción
}

resource "azurerm_mssql_database" "sql_db_ventas" {
  name      = "sqldb-ventas-5756067"
  server_id = azurerm_mssql_server.sql_server_ventas.id
  sku_name  = "Basic"
}

# 4. Azure Data Factory
resource "azurerm_data_factory" "adf_ventas" {
  name                = "adf-ventas-5756067"
  location            = azurerm_resource_group.rg_ventas.location
  resource_group_name = azurerm_resource_group.rg_ventas.name
}
