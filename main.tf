terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource Groups
resource "azurerm_resource_group" "landing_zone_mgt" {
  name     = "rg-landing-zone-mgt"
  location = var.location
}

resource "azurerm_resource_group" "dev_application_spoke" {
  name     = "rg-dev-application-spoke"
  location = var.location
}

# Log Analytics Workspace for Security Monitoring
resource "azurerm_log_analytics_workspace" "security" {
  name                = "law-security-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.landing_zone_mgt.name
  location            = azurerm_resource_group.landing_zone_mgt.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
}

# Key Vault for Secrets Management
resource "azurerm_key_vault" "main" {
  name                       = "kv-lz-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.landing_zone_mgt.name
  location                   = azurerm_resource_group.landing_zone_mgt.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = true
  soft_delete_retention_days = 90

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}

# Virtual Networks
resource "azurerm_virtual_network" "ldz_vnet" {
  name                = "ldz-vnet"
  resource_group_name = azurerm_resource_group.landing_zone_mgt.name
  location            = azurerm_resource_group.landing_zone_mgt.location
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "ldz_subnet" {
  name                 = "ldz-subnet"
  resource_group_name  = azurerm_resource_group.landing_zone_mgt.name
  virtual_network_name = azurerm_virtual_network.ldz_vnet.name
  address_prefixes     = ["10.1.0.0/24"]
}

# Network Security Groups
resource "azurerm_network_security_group" "ldz_nsg" {
  name                = "ldz-nsg"
  resource_group_name = azurerm_resource_group.landing_zone_mgt.name
  location            = azurerm_resource_group.landing_zone_mgt.location

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "ldz_subnet_nsg" {
  subnet_id                 = azurerm_subnet.ldz_subnet.id
  network_security_group_id = azurerm_network_security_group.ldz_nsg.id
}

resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.landing_zone_mgt.name
  virtual_network_name = azurerm_virtual_network.ldz_vnet.name
  address_prefixes     = ["10.1.1.0/26"]
}

resource "azurerm_virtual_network" "dev_spoke_vnet" {
  name                = "dev-spoke-vnet"
  resource_group_name = azurerm_resource_group.dev_application_spoke.name
  location            = azurerm_resource_group.dev_application_spoke.location
  address_space       = ["10.2.0.0/16"]
}

resource "azurerm_subnet" "dev_spoke_subnet" {
  name                 = "dev-spoke-subnet"
  resource_group_name  = azurerm_resource_group.dev_application_spoke.name
  virtual_network_name = azurerm_virtual_network.dev_spoke_vnet.name
  address_prefixes     = ["10.2.0.0/24"]
}

resource "azurerm_network_security_group" "dev_spoke_nsg" {
  name                = "dev-spoke-nsg"
  resource_group_name = azurerm_resource_group.dev_application_spoke.name
  location            = azurerm_resource_group.dev_application_spoke.location

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "dev_spoke_subnet_nsg" {
  subnet_id                 = azurerm_subnet.dev_spoke_subnet.id
  network_security_group_id = azurerm_network_security_group.dev_spoke_nsg.id
}

# Route Tables
resource "azurerm_route_table" "ldz_udr" {
  name                = "ldz-udr"
  resource_group_name = azurerm_resource_group.landing_zone_mgt.name
  location            = azurerm_resource_group.landing_zone_mgt.location
}

resource "azurerm_subnet_route_table_association" "ldz_subnet_udr" {
  subnet_id      = azurerm_subnet.ldz_subnet.id
  route_table_id = azurerm_route_table.ldz_udr.id
}

resource "azurerm_route_table" "dev_spoke_udr" {
  name                = "dev-spoke-udr"
  resource_group_name = azurerm_resource_group.dev_application_spoke.name
  location            = azurerm_resource_group.dev_application_spoke.location
}

resource "azurerm_subnet_route_table_association" "dev_spoke_subnet_udr" {
  subnet_id      = azurerm_subnet.dev_spoke_subnet.id
  route_table_id = azurerm_route_table.dev_spoke_udr.id
}

# Virtual WAN
resource "azurerm_virtual_wan" "demo_vwan" {
  name                = "demo-vwan"
  resource_group_name = azurerm_resource_group.landing_zone_mgt.name
  location            = azurerm_resource_group.landing_zone_mgt.location
  type                = "Standard"
}

resource "azurerm_virtual_hub" "demo_vwan_hub" {
  name                = "demo-vwan-hub"
  resource_group_name = azurerm_resource_group.landing_zone_mgt.name
  location            = azurerm_resource_group.landing_zone_mgt.location
  virtual_wan_id      = azurerm_virtual_wan.demo_vwan.id
  address_prefix      = "10.23.0.0/23"
}

# VNet Connections to vWAN Hub
resource "azurerm_virtual_hub_connection" "ldz_connect" {
  name                      = "ldz-connect"
  virtual_hub_id            = azurerm_virtual_hub.demo_vwan_hub.id
  remote_virtual_network_id = azurerm_virtual_network.ldz_vnet.id

  routing {
    associated_route_table_id = azurerm_virtual_hub.demo_vwan_hub.default_route_table_id
    propagated_route_table {
      route_table_ids = [azurerm_virtual_hub.demo_vwan_hub.default_route_table_id]
    }
  }
}

resource "azurerm_virtual_hub_connection" "dev_spoke_connect" {
  name                      = "dev-spoke-connect"
  virtual_hub_id            = azurerm_virtual_hub.demo_vwan_hub.id
  remote_virtual_network_id = azurerm_virtual_network.dev_spoke_vnet.id

  routing {
    associated_route_table_id = azurerm_virtual_hub.demo_vwan_hub.default_route_table_id
    propagated_route_table {
      route_table_ids = [azurerm_virtual_hub.demo_vwan_hub.default_route_table_id]
    }
  }
}

# Network Interfaces
resource "azurerm_network_interface" "ldz_vm_nic" {
  name                = "ldz-vm-nic"
  resource_group_name = azurerm_resource_group.landing_zone_mgt.name
  location            = azurerm_resource_group.landing_zone_mgt.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.ldz_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "dev_spoke_vm_nic" {
  name                = "dev-spoke-vm-nic"
  resource_group_name = azurerm_resource_group.dev_application_spoke.name
  location            = azurerm_resource_group.dev_application_spoke.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dev_spoke_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Virtual Machines with Security Extensions
resource "azurerm_linux_virtual_machine" "ldz_vm" {
  name                            = "ldz-vm"
  resource_group_name             = azurerm_resource_group.landing_zone_mgt.name
  location                        = azurerm_resource_group.landing_zone_mgt.location
  size                            = "Standard_D2s_v3"
  admin_username                  = "azureuser"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.ldz_vm_nic.id]
  patch_mode                      = "AutomaticByPlatform"

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching                   = "ReadWrite"
    storage_account_type      = "Premium_LRS"
    disk_encryption_set_id    = azurerm_disk_encryption_set.main.id
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_virtual_machine_extension" "ldz_vm_monitor" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.ldz_vm.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

resource "azurerm_linux_virtual_machine" "dev_spoke_vm" {
  name                            = "dev-spoke-vm"
  resource_group_name             = azurerm_resource_group.dev_application_spoke.name
  location                        = azurerm_resource_group.dev_application_spoke.location
  size                            = "Standard_D2s_v3"
  admin_username                  = "azureuser"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.dev_spoke_vm_nic.id]
  patch_mode                      = "AutomaticByPlatform"

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching                   = "ReadWrite"
    storage_account_type      = "Premium_LRS"
    disk_encryption_set_id    = azurerm_disk_encryption_set.main.id
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_virtual_machine_extension" "dev_spoke_vm_monitor" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.dev_spoke_vm.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

# Disk Encryption Set
resource "azurerm_disk_encryption_set" "main" {
  name                = "des-lz-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.landing_zone_mgt.name
  location            = azurerm_resource_group.landing_zone_mgt.location
  key_vault_key_id    = azurerm_key_vault_key.disk_encryption.id

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_key_vault_key" "disk_encryption" {
  name         = "disk-encryption-key"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]

  depends_on = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = ["Get", "Create", "Delete", "List", "Update", "GetRotationPolicy", "SetRotationPolicy"]
}

resource "azurerm_key_vault_access_policy" "disk_encryption" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = azurerm_disk_encryption_set.main.identity[0].tenant_id
  object_id    = azurerm_disk_encryption_set.main.identity[0].principal_id

  key_permissions = ["Get", "WrapKey", "UnwrapKey"]
}

# Microsoft Defender for Cloud
resource "azurerm_security_center_subscription_pricing" "vm" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "storage" {
  tier          = "Standard"
  resource_type = "StorageAccounts"
}

resource "azurerm_security_center_subscription_pricing" "keyvault" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}

resource "azurerm_security_center_contact" "main" {
  email               = var.security_contact_email
  alert_notifications = true
  alerts_to_admins    = true
}

resource "azurerm_security_center_workspace" "main" {
  scope        = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  workspace_id = azurerm_log_analytics_workspace.security.id
}

# Azure Bastion
resource "azurerm_public_ip" "bastion_pip" {
  name                = "ldz-bastion-pip"
  resource_group_name = azurerm_resource_group.landing_zone_mgt.name
  location            = azurerm_resource_group.landing_zone_mgt.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "ldz_bastion" {
  name                = "ldz-bastion"
  resource_group_name = azurerm_resource_group.landing_zone_mgt.name
  location            = azurerm_resource_group.landing_zone_mgt.location
  sku                 = "Standard"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }
}
