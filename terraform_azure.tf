variable "resource_group" {
  default = "your-resource-group"
}

variable "location" {
  description = "The location/region where the virtual network resides."
  default     = "West US"
}

variable "vnet" {
    default = "your-vnet"
}


# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = "your-subsciption-id"
    client_id       = "your-client-id"
    client_secret   = "your-client-secret"
    tenant_id       = "your-tenant-id"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "myterraformgroup" {
    name     = "${var.resource_group}"
    location = "${var.location}"

    tags {
        environment = "Terraform Demo"
    }
}

resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.myterraformgroup.name}"
    }

    byte_length = 8
}

#Create a public IP for your VM
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "myPublicIP"
    location                     = "${var.location}"
    resource_group_name          = "${azurerm_resource_group.myterraformgroup.name}"
    public_ip_address_allocation = "static"

    tags {
        environment = "Terraform Demo"
    }
}

#Create a subnet for your VM
resource "azurerm_subnet" "myterraformsubnet" {
    name                 = "mySubnet"
    resource_group_name  = "${azurerm_resource_group.myterraformgroup.name}"
    virtual_network_name = "${var.vnet}"
    address_prefix       = "10.0.2.0/24"
}

#need to create a new NIC for your VM
resource "azurerm_network_interface" "myterraformnic" {
    name                = "myNIC"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.myterraformgroup.name}"

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = "${azurerm_subnet.myterraformsubnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.myterraformpublicip.id}"
    }

    tags {
        environment = "Terraform Demo"
    }
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.myterraformgroup.name}"
    location                    = "${var.location}"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags {
        environment = "Terraform Demo"
    }
}


# Create virtual machine
resource "azurerm_virtual_machine" "myterraformvm" {
    name                  = "myVM"
    location              = "${var.location}"
    resource_group_name   = "${azurerm_resource_group.myterraformgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.myterraformnic.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "myvm"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB9wDbBA1ypQoGZi96aUMF+zAzq1ro22nV5KzgOwCVM4aTDKkkpJAor0zvri3HztmlbeBqCuOwYCqSkoVS6PN9yfNBlHQWUC7LvG2GT0KfDT+ToPuq5GpATexIxUaRg+vSAmXZlIM4aRwUvxnWlhSkRMnRfeYQOQL/WdAwqVyWAdTJYuGmUa0ktekbk3DIE/VkbmyRUmve4oWaFNMnbmoxh8XGFMSExKi02k5VOPHwoGXVIVtVIWMq7WhJb2IvpLwCXay3M0A9cnt991KFFt+o3lpoIfJABjxHGMBzQd/pTXqyQZsOPRzGx43Jpvc6M7G1x2MMvO1C6xL18hd+56RUDbHJ5B9Uw053a1fsVdRX1B+pTWB6mDtWHOWZHjdmk//AB9yq55hnWHEwI3UpHoBIFoV6YNGyQbQGlnUPGPQ814eJ4QP1sIJdDpl6muAKlK6xsUvuZ6WoTuZ1sKVlnuscZP31NT94CzcxpsRoHe0cHdrfCfIldQNfSEhjMZ45qOZ6Y1/lZDYBj7KpIA98lfpJHhX7bNo5YsgcUisps0KYqJYU6YJj9+n/5poyMv04Ga1gGmSIsyOaSdLxeL4CMxcee/bWLDXEe9JydKLetYlp1hnouBKstFkTFCA4rIBqe69LaXYLmdDt8LuCrFsnFJ4L5iPiCtJwsL7R allahnal@microsoft.com"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.mystorageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "Terraform Demo"
    }
}