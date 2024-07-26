terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = "true"
}

data "azurerm_resource_group" "sandbox-rg" {
  name = "mbleezarde-sandbox"
}

resource "azurerm_virtual_network" "sandbox-vn" {
  name                = "Dev-vnet"
  location            = "East US"
  resource_group_name = data.azurerm_resource_group.sandbox-rg.name
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet" "sandbox-sn" {
  name                 = "Dev-subnet"
  resource_group_name  = data.azurerm_resource_group.sandbox-rg.name
  virtual_network_name = azurerm_virtual_network.sandbox-vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "sandbox-nsg" {
  name                = "Dev-nsg"
  location            = azurerm_virtual_network.sandbox-vn.location
  resource_group_name = data.azurerm_resource_group.sandbox-rg.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "sandbox-nsr" {
  name                        = "Dev-nsr"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.sourceIP
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.sandbox-rg.name
  network_security_group_name = azurerm_network_security_group.sandbox-nsg.name

}

resource "azurerm_subnet_network_security_group_association" "sandbox-nsg-ass" {
  subnet_id                 = azurerm_subnet.sandbox-sn.id
  network_security_group_id = azurerm_network_security_group.sandbox-nsg.id
}

resource "azurerm_public_ip" "sandbox-Ip1" {
  name                = "DevPublicIp1"
  resource_group_name = data.azurerm_resource_group.sandbox-rg.name
  location            = azurerm_virtual_network.sandbox-vn.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "sandbox-nic" {
  name                = "Dev-nic1"
  location            = azurerm_virtual_network.sandbox-vn.location
  resource_group_name = data.azurerm_resource_group.sandbox-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sandbox-sn.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.sandbox-Ip1.id
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_linux_virtual_machine" "sandbox-Lvm" {
  name                = "Dev-L-01"
  resource_group_name = data.azurerm_resource_group.sandbox-rg.name
  location            = azurerm_virtual_network.sandbox-vn.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.sandbox-nic.id,
  ]

  custom_data = filebase64("customdata.tpl")
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/terradevkey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "adminuser",
      identityfile = "~/.ssh/terradevkey"
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
  }

  tags = {
    environment = "dev"
  }
}

data "azurerm_public_ip" "sandbox_ip_data" {
  name                = azurerm_public_ip.sandbox-Ip1.name
  resource_group_name = data.azurerm_resource_group.sandbox-rg.name
}

output "Sandbox-ip-out" {
  value = "${azurerm_linux_virtual_machine.sandbox-Lvm.name}: ${data.azurerm_public_ip.sandbox_ip_data.ip_address}"
}