terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.5.0"
    }
  }
}

provider "azurerm" {
  features {

  }
}


#Resource group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.resource_id}-${var.environment}"
  location = var.location
  tags     = var.resource_tags
}
/*
data "azurerm_resource_group" "rg" {
  name = "rg-idhi-prd"

}
*/

resource "azurerm_virtual_network" "vnet-spoke1" { //Define virtual network for workloads
  name                = "vnet-spoke1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.20.0.0/16"]
  tags                = var.resource_tags
}



resource "azurerm_subnet" "snet-spoke1" { //Define subnet inside virtual network
  name                 = "snet-spoke1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet-spoke1.name
  address_prefixes     = ["10.20.0.0/24"]


}

resource "azurerm_network_interface" "nic-vm" { //Define network interface for the vm
  name                = "nic-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "nic-vm-config"
    subnet_id                     = azurerm_subnet.snet-spoke1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip-vm.id
  }
  tags = var.resource_tags

}

/*
resource "azurerm_network_interface" "nic-2" { //Define second network interface
  name                = "nic-2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  ip_configuration {
    name = "nic2-config"
    # public_ip_address_id = azurerm_public_ip.public_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.snet-spoke1.id


  }
  tags = var.resource_tags
}
*/

resource "azurerm_public_ip" "pip-vm" { //defining the public IP
  name                = "vm-pub-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  domain_name_label = "sandbox" //defining the dns name
  tags = var.resource_tags
}


resource "azurerm_network_security_group" "nsg" { //Define network security group
  name                = "nsg-${var.resource_id}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  security_rule { //Open https inbound only
    name                       = "https only"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.resource_tags

}

resource "azurerm_subnet_network_security_group_association" "nsg-association" { //Associate network security group with the workload subnet (snet-spoke1)
  subnet_id                 = azurerm_subnet.snet-spoke1.id
  network_security_group_id = azurerm_network_security_group.nsg.id

}


resource "azurerm_storage_account" "storageacc" { //Define storage account
  name                     = "stsandbox"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  tags                     = var.resource_tags
}

resource "azurerm_managed_disk" "vm-datadisk" {
  name                 = "vm-datadisk"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "50"

  tags = var.resource_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "datadisk" {
  managed_disk_id    = azurerm_managed_disk.vm-datadisk.id
  virtual_machine_id = azurerm_windows_virtual_machine.vm.id
  lun                = "0"
  caching            = "ReadWrite"

}

resource "azurerm_windows_virtual_machine" "vm" { //Define the virtual machine
  name                = "vm-${var.resource_id}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B2s"     //Define VM size
  admin_username      = var.admin_username //Supplied via a variable value file
  admin_password      = var.admin_password //Supplied via a variable value file
  network_interface_ids = [                //Attach the network interfaces
    azurerm_network_interface.nic-vm.id,
#    azurerm_network_interface.nic-2.id


  ]


  os_disk { //Define the disk for the OS
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }



  source_image_reference { //Define VM OS
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  tags = var.resource_tags

}

resource "azurerm_virtual_machine_extension" "vm_extension_install_iis" { //Install IIS after VM creation
  name                       = "vm_extension_install_iis"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools"
    }
SETTINGS
  tags     = var.resource_tags
}
/*
resource "azurerm_recovery_services_vault" "rsv" { //Define Revocery Services Vault
  name                = "rsv-${var.resource_id}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  tags                = var.resource_tags
}

resource "azurerm_backup_policy_vm" "vm-backup-policy" { //Define backup policy
  name                = "vm-${var.resource_id}-${var.environment}-backup-policy"
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.rsv.name
  retention_weekly {
    weekdays = ["Friday"]
    count    = 1
  }

  backup {
    frequency = "Weekly"
    weekdays  = ["Friday"]
    time      = "23:00"

  }
}

resource "azurerm_backup_protected_vm" "vm" { //Protect the  VM with the defined backup policy
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.rsv.name
  source_vm_id        = azurerm_windows_virtual_machine.vm.id
  backup_policy_id    = azurerm_backup_policy_vm.vm-backup-policy.id
}
*/

resource "azurerm_virtual_network" "vnet-hub" { //Define virtual network "hub" for shared services like Bastion host
  name                = "vnet-hub"
  address_space       = ["10.10.10.0/24"]
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = var.resource_tags

}

resource "azurerm_subnet" "bastion" { //Define subnet for the Bastion host
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet-hub.name
  address_prefixes     = ["10.10.10.0/27"]

}

resource "azurerm_public_ip" "pip-bastion" { //Define public ip for the Bastion host 
  name                = "pip-bastion"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.resource_tags

}

resource "azurerm_bastion_host" "bastion-host" { //Define the bastion host and assign its ip configurationk
  name                = "bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.resource_tags

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.pip-bastion.id
  }

}

resource "azurerm_virtual_network_peering" "peer-1" { //Peer the spoke1 virtual network to the hub virtual network
  name                      = "peer-vnet-to-hub"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet-spoke1.name
  remote_virtual_network_id = azurerm_virtual_network.vnet-hub.id

}

resource "azurerm_virtual_network_peering" "peer-2" { //Peer the hub virtual network to the spoke1 virtual network
  name                      = "peer-hub-to-vnet"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet-hub.name
  remote_virtual_network_id = azurerm_virtual_network.vnet-spoke1.id

}

