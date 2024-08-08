resource "azurerm_subnet" "cluster_subnet" {
  name                                      = "cluster-subnet"
  resource_group_name                       = var.resource_group_name
  virtual_network_name                      = azurerm_virtual_network.vnet.name
  address_prefixes                          = ["10.1.1.0/24"]
  private_endpoint_network_policies_enabled = true
}
