resource "azurerm_resource_group" "rgblock" {
  name     = "ram-rgs"
  location = "eastus"

}


resource "azurerm_virtual_network" "vnetblock" {
  depends_on          = [azurerm_resource_group.rgblock]
  name                = "rmVnet"
  address_space       = ["10.0.0.0/16"]
  location            = "eastus"
  resource_group_name = "ram-rgs"

}


resource "azurerm_subnet" "subnetblock" {
  depends_on           = [azurerm_virtual_network.vnetblock]
  name                 = "rmSubnet"
  resource_group_name  = "ram-rgs"
  virtual_network_name = "rmVnet"
  address_prefixes     = ["10.0.1.0/24"]
}


resource "azurerm_public_ip" "pipblock" {
  depends_on          = [azurerm_resource_group.rgblock]
  name                = "myPublicIP"
  location            = "eastus"
  resource_group_name = "ram-rgs"
  allocation_method   = "Dynamic"
}



resource "azurerm_network_security_group" "nsglock" {
  depends_on          = [azurerm_resource_group.rgblock]
  name                = "rmNetworkSecurityGroup"
  location            = "eastus"
  resource_group_name = "ram-rgs"

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }


}


resource "azurerm_network_interface" "nicblock" {
  depends_on          = [azurerm_resource_group.rgblock, azurerm_virtual_network.vnetblock, azurerm_subnet.subnetblock, azurerm_public_ip.pipblock]
  name                = "rmNIC"
  location            = "eastus"
  resource_group_name = "ram-rgs"

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = azurerm_subnet.subnetblock.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pipblock.id
  }

}

resource "azurerm_network_interface_security_group_association" "nsgassblock" {
  depends_on                = [azurerm_network_security_group.nsglock]
  network_interface_id      = azurerm_network_interface.nicblock.id
  network_security_group_id = azurerm_network_security_group.nsglock.id
}


resource "azurerm_linux_virtual_machine" "vmblock" {
  depends_on = [ azurerm_network_interface.nicblock ]
  name                  = "ram-Vmachine"
  resource_group_name   = "ram-rgs"
  location              = "eastus"
  size                  = "Standard_F2"
  network_interface_ids = [azurerm_network_interface.nicblock.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  computer_name                   = "rmvm"
  admin_username                  = "azureuser"
  disable_password_authentication = false
  admin_password                  = "adminrm@1234"

  connection {
    host     = self.public_ip_address
    user     = "azureuser"
    password = "adminrm@1234"
    type     = "ssh"
    timeout  = "2m"
  }

  provisioner "file" {
    source      = "index.html"      // Mera Laptop
    destination = "/tmp/index.html" //remote VM
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install nginx -y",
      "sudo cp /tmp/index.html /var/www/html",
      "sudo systemctl restart nginx"
    ]
  }

  provisioner "local-exec" {
    command = "echo complete > completed.txt"
  }
}

resource "azurerm_kubernetes_cluster" "example" {
  name                = "example-aks1"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "exampleaks1"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
  }
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.example.kube_config[0].client_certificate
  sensitive = true
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.example.kube_config_raw

  sensitive = true
}



