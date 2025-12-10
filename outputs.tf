output "landing_zone_vnet_id" {
  value       = azurerm_virtual_network.ldz_vnet.id
  description = "Landing Zone VNet ID"
}

output "dev_spoke_vnet_id" {
  value       = azurerm_virtual_network.dev_spoke_vnet.id
  description = "Dev Spoke VNet ID"
}

output "ldz_vm_private_ip" {
  value       = azurerm_network_interface.ldz_vm_nic.private_ip_address
  description = "Landing Zone VM private IP address"
}

output "dev_spoke_vm_private_ip" {
  value       = azurerm_network_interface.dev_spoke_vm_nic.private_ip_address
  description = "Dev Spoke VM private IP address"
}

output "bastion_host_id" {
  value       = azurerm_bastion_host.ldz_bastion.id
  description = "Azure Bastion Host ID"
}

output "virtual_wan_id" {
  value       = azurerm_virtual_wan.demo_vwan.id
  description = "Virtual WAN ID"
}

output "virtual_hub_id" {
  value       = azurerm_virtual_hub.demo_vwan_hub.id
  description = "Virtual Hub ID"
}

output "key_vault_id" {
  value       = azurerm_key_vault.main.id
  description = "Key Vault ID"
}

output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.security.id
  description = "Log Analytics Workspace ID"
}

output "disk_encryption_set_id" {
  value       = azurerm_disk_encryption_set.main.id
  description = "Disk Encryption Set ID"
}
