# Configuración de Terraform y Providers (Idempotencia asegurada vía state remoto)
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstatecredi"
    container_name       = "tfstate"
    key                  = "fintech.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}

# Grupo de Recursos Principal
resource "azurerm_resource_group" "rg" {
  name     = "rg-credirapido-${var.environment}"
  location = var.location
}

# ---------------------------------------------------------
# Módulo de Red (VNet Injection & Private Endpoints)
# ---------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-fintech-${var.environment}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "snet_aca" {
  name                 = "snet-aca"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/23"]
}

resource "azurerm_network_security_group" "nsg_aca" {
  name                = "nsg-aca-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet_network_security_group_association" "snet_aca_nsg" {
  subnet_id                 = azurerm_subnet.snet_aca.id
  network_security_group_id = azurerm_network_security_group.nsg_aca.id
}

resource "azurerm_subnet" "snet_pe" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

# ---------------------------------------------------------
# Módulo de Seguridad y Gobierno (Key Vault & RBAC)
# ---------------------------------------------------------
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                       = "kv-credirapido-${var.environment}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = true

  # Restricción de red: Acceso solo desde la VNet (Private Endpoint planeado)
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

resource "azurerm_private_dns_zone" "dns_kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_endpoint" "pe_kv" {
  name                = "pe-kv-credirapido-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.snet_pe.id

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "dns-group-kv"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_kv.id]
  }
}

# ---------------------------------------------------------
# Módulo de Base de Datos (PostgreSQL Flexible Server)
# ---------------------------------------------------------
# Integración con Private DNS Zone para PostgreSQL
resource "azurerm_private_dns_zone" "dns_pg" {
  name                = "${var.environment}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_postgresql_flexible_server" "pg" {
  name                   = "pg-credirapido-${var.environment}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = var.pg_version
  administrator_login    = var.db_admin_user
  administrator_password = var.db_admin_password # Idealmente inyectado en runtime
  storage_mb             = 32768
  sku_name               = "GP_Standard_D2s_v3"

  # Mapeo a red privada / Delegación
  delegated_subnet_id    = azurerm_subnet.snet_pe.id
  private_dns_zone_id    = azurerm_private_dns_zone.dns_pg.id
}

# ---------------------------------------------------------
# Módulo de Cómputo (Azure Container Apps)
# ---------------------------------------------------------
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-credirapido-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "cae" {
  name                       = "cae-credirapido-${var.environment}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  # Inyección en VNet de la plataforma PaaS
  infrastructure_subnet_id   = azurerm_subnet.snet_aca.id
}

resource "azurerm_container_app" "app" {
  name                         = "ca-credito-api"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  # Managed Identity para acceso seguro a Key Vault (Mínimo Privilegio)
  identity {
    type = "SystemAssigned"
  }

  template {
    container {
      name   = "credito-api"
      image  = "ghcr.io/credirapido/credito-api:${var.api_image_tag}"
      cpu    = 0.5
      memory = "1Gi"
    }

    # Configuración de Autoescalado KEDA (escalado a cero soportado)
    min_replicas = 0
    max_replicas = 10
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# Principio de Mínimo Privilegio: Dar acceso al microservicio solo para LEER secretos del KV
resource "azurerm_role_assignment" "kv_secrets_user" {
  principal_id         = azurerm_container_app.app.identity[0].principal_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.kv.id
}
