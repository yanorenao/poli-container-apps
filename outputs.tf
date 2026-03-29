output "resource_group_name" {
  description = "El nombre del grupo de recursos aprovisionado"
  value       = azurerm_resource_group.rg.name
}

output "api_url" {
  description = "URL externa de la Container App expuesta"
  value       = azurerm_container_app.app.ingress[0].fqdn
}

output "database_fqdn" {
  description = "Nombre de dominio calificado de la base de datos PostgreSQL"
  value       = azurerm_postgresql_flexible_server.pg.fqdn
}

output "key_vault_uri" {
  description = "URI del Key Vault"
  value       = azurerm_key_vault.kv.vault_uri
}
