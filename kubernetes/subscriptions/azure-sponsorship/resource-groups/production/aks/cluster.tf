resource "azurerm_kubernetes_cluster" "aks" {
  name                        = "aks-cluster"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  dns_prefix                  = var.resource_group_name

  automatic_channel_upgrade = "patch"

  private_cluster_enabled = false
  default_node_pool {
    enable_node_public_ip       = false
    name                        = "system"
    node_count                  = 1
    vm_size                     = var.instance_type
    vnet_subnet_id              = azurerm_subnet.cluster_subnet.id
    temporary_name_for_rotation = "systemtemp"
 }
  identity { 
    type = "SystemAssigned"
 }

}
