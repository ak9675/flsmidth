

provider "azurerm" {
  features {}
}


locals {
  resource_group="app-grp"
  location="eastus"  
}


resource "azurerm_resource_group" "app_grp"{
  name=local.resource_group
  location=local.location
}

resource "azurerm_virtual_network" "app_network" {
  name                = "app-network"
  location            = local.location
  resource_group_name = azurerm_resource_group.app_grp.name
  address_space       = ["10.0.0.0/16"]  
  depends_on = [
    azurerm_resource_group.app_grp
  ]
}

resource "azurerm_subnet" "SubnetA" {
  name                 = "SubnetA"
  resource_group_name  = azurerm_resource_group.app_grp.name
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.0.0/24"]
  depends_on = [
    azurerm_virtual_network.app_network
  ]
}

// This interface is for appvm1
resource "azurerm_network_interface" "app_interface1" {
  name                = "app-interface1"
  location            = azurerm_resource_group.app_grp.location
  resource_group_name = azurerm_resource_group.app_grp.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SubnetA.id
    private_ip_address_allocation = "Dynamic"    
  }

  depends_on = [
    azurerm_virtual_network.app_network,
    azurerm_subnet.SubnetA
  ]
}

// This interface is for appvm2
resource "azurerm_network_interface" "app_interface2" {
  name                = "app-interface2"
  location            = azurerm_resource_group.app_grp.location
  resource_group_name = azurerm_resource_group.app_grp.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SubnetA.id
    private_ip_address_allocation = "Dynamic"    
  }

  depends_on = [
    azurerm_virtual_network.app_network,
    azurerm_subnet.SubnetA
  ]
}

// This is the resource for appvm1
resource "azurerm_windows_virtual_machine" "app_vm1" {
  name                = "appvm1"
  resource_group_name = azurerm_resource_group.app_grp.name
  location            = azurerm_resource_group.app_grp.location
  size                = "Standard_D2s_v3"
  admin_username      = "demousr"
  admin_password      = "Azure@123"
  availability_set_id = azurerm_availability_set.app_set.id
  network_interface_ids = [
    azurerm_network_interface.app_interface1.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  depends_on = [
    azurerm_network_interface.app_interface1,
    azurerm_availability_set.app_set
  ]
}

// This is the resource for appvm2
resource "azurerm_windows_virtual_machine" "app_vm2" {
  name                = "appvm2"
  resource_group_name = azurerm_resource_group.app_grp.name
  location            = azurerm_resource_group.app_grp.location
  size                = "Standard_D2s_v3"
  admin_username      = "demousr"
  admin_password      = "Azure@123"
  availability_set_id = azurerm_availability_set.app_set.id
  network_interface_ids = [
    azurerm_network_interface.app_interface2.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  depends_on = [
    azurerm_network_interface.app_interface2,
    azurerm_availability_set.app_set
  ]
}


resource "azurerm_availability_set" "app_set" {
  name                = "app-set"
  location            = azurerm_resource_group.app_grp.location
  resource_group_name = azurerm_resource_group.app_grp.name
  platform_fault_domain_count = 3
  platform_update_domain_count = 3  
  depends_on = [
    azurerm_resource_group.app_grp
  ]
}

resource "azurerm_storage_account" "appstore" {
  name                     = "anshu96758899"
  resource_group_name      = azurerm_resource_group.app_grp.name
  location                 = azurerm_resource_group.app_grp.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_nested_items_to_be_public  = true
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = "anshu96758899"
  container_access_type = "blob"
  depends_on=[
    azurerm_storage_account.appstore
    ]
}

# Here we are uploading our IIS Configuration script as a blob
# to the Azure storage account

resource "azurerm_storage_blob" "IIS_config" {
  name                   = "IIS_Config.ps1"
  storage_account_name   = "anshu96758899"
  storage_container_name = "data"
  type                   = "Block"
  source                 = "IIS_Config.ps1"
   depends_on=[azurerm_storage_container.data]
}

// This is the extension for appvm1
resource "azurerm_virtual_machine_extension" "vm_extension1" {
  name                 = "appvm-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.app_vm1.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on = [
    azurerm_storage_blob.IIS_config
  ]
  settings = <<SETTINGS
    {
        "fileUris": ["https://${azurerm_storage_account.appstore.name}.blob.core.windows.net/data/IIS_Config.ps1"],
          "commandToExecute": "powershell -ExecutionPolicy Unrestricted -file IIS_Config.ps1"     
    }
SETTINGS
}


// This is the extension for appvm2
resource "azurerm_virtual_machine_extension" "vm_extension2" {
  name                 = "appvm-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.app_vm2.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on = [
    azurerm_storage_blob.IIS_config
  ]
  settings = <<SETTINGS
    {
        "fileUris": ["https://${azurerm_storage_account.appstore.name}.blob.core.windows.net/data/IIS_Config.ps1"],
          "commandToExecute": "powershell -ExecutionPolicy Unrestricted -file IIS_Config.ps1"     
    }
SETTINGS
}


resource "azurerm_network_security_group" "app_nsg" {
  name                = "app-nsg"
  location            = azurerm_resource_group.app_grp.location
  resource_group_name = azurerm_resource_group.app_grp.name

# We are creating a rule to allow traffic on port 80
  security_rule {
    name                       = "Allow_HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.SubnetA.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
  depends_on = [
    azurerm_network_security_group.app_nsg
  ]
}

resource "azurerm_public_ip" "load_ip" {
  name                = "load-ip"
  location            = azurerm_resource_group.app_grp.location
  resource_group_name = azurerm_resource_group.app_grp.name
  allocation_method   = "Static"
  sku = "Standard"
}

resource "azurerm_lb" "app_balancer" {
  name                = "app-balancer"
  location            = azurerm_resource_group.app_grp.location
  resource_group_name = azurerm_resource_group.app_grp.name
  sku = "Standard"
  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.load_ip.id
  }
  depends_on = [
    azurerm_public_ip.load_ip
  ]
}

resource "azurerm_lb_backend_address_pool" "PoolA" {
  loadbalancer_id = azurerm_lb.app_balancer.id
  name            = "PoolA"

  depends_on = [
    azurerm_lb.app_balancer
  ]
}

resource "azurerm_lb_backend_address_pool_address" "appvm1_address" {
  name                    = "appvm1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.PoolA.id
  virtual_network_id      = azurerm_virtual_network.app_network.id
  ip_address              = azurerm_network_interface.app_interface1.private_ip_address
  depends_on = [
    azurerm_lb_backend_address_pool.PoolA
  ]
}

resource "azurerm_lb_backend_address_pool_address" "appvm2_address" {
  name                    = "appvm2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.PoolA.id
  virtual_network_id      = azurerm_virtual_network.app_network.id
  ip_address              = azurerm_network_interface.app_interface2.private_ip_address
  depends_on = [
    azurerm_lb_backend_address_pool.PoolA
  ]
}


resource "azurerm_lb_probe" "ProbeA" {
  loadbalancer_id = azurerm_lb.app_balancer.id
  name            = "ProbeA"
  port            = 80
  depends_on = [
    azurerm_lb.app_balancer
  ]
}

resource "azurerm_lb_rule" "RuleA" {
  loadbalancer_id                = azurerm_lb.app_balancer.id
  name                           = "RuleA"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_ids = [azurerm_lb_backend_address_pool.PoolA.id]
  probe_id = azurerm_lb_probe.ProbeA.id
  depends_on = [
    azurerm_lb.app_balancer,
    azurerm_lb_probe.ProbeA
  ]
}