terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "> 4.23.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 1. Grupo de Recursos para ProyectoVentas
resource "azurerm_resource_group" "rg_ventas" {
  name     = "rg-ventas-5756067"
  location = "Brazil South"
}

# 2. Almacenamiento (Data Lake Gen2 para Bronze/Silver)
resource "azurerm_storage_account" "sa_ventas" {
  name                     = "saventas5756067"
  resource_group_name      = azurerm_resource_group.rg_ventas.name
  location                 = azurerm_resource_group.rg_ventas.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = "true"
}

resource "azurerm_storage_container" "bronze" {
  name                  = "bronze"
  storage_account_id    = azurerm_storage_account.sa_ventas.id
  container_access_type = "blob"
}

resource "azurerm_storage_container" "silver" {
  name                  = "silver"
  storage_account_id    = azurerm_storage_account.sa_ventas.id
  container_access_type = "blob"
}

# 3. Servidor SQL y Base de Datos (Data Warehouse Gold)
resource "azurerm_mssql_server" "sql_server_ventas" {
  name                         = "sql-ucb-ventas-5756067"
  resource_group_name          = azurerm_resource_group.rg_ventas.name
  location                     = azurerm_resource_group.rg_ventas.location
  version                      = "12.0"
  administrator_login          = "adminventas"
  administrator_login_password = "S3cur3_P@ssw0rd_2026"
}

resource "azurerm_mssql_firewall_rule" "allow_all_ventas" {
  name             = "AllowAll"
  server_id        = azurerm_mssql_server.sql_server_ventas.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

resource "azurerm_mssql_database" "dw_ventas" {
  name         = "dw_ventas"
  server_id    = azurerm_mssql_server.sql_server_ventas.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"
  max_size_gb  = 2
  sku_name     = "S0"
}

# 4. Azure Data Factory
resource "azurerm_data_factory" "adf_ventas" {
  name                = "adf-ucb-ventas-5756067"
  location            = azurerm_resource_group.rg_ventas.location
  resource_group_name = azurerm_resource_group.rg_ventas.name

  github_configuration {
    account_name    = "black795"
    branch_name     = "main"
    repository_name = "ProyectoVentas"
    root_folder     = "/"
  }
}
