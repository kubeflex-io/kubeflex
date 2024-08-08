resource "azurerm_virtual_network" "vnet" {
  name                = "cluster-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
}