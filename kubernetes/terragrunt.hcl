locals {
  default_yaml_path     = find_in_parent_folders("empty.yaml")
  org                   = yamldecode(file(find_in_parent_folders("org.yaml")))
  subscription          = yamldecode(file(find_in_parent_folders("subscription.yaml")))
  resource_group        = yamldecode(file(find_in_parent_folders("resource_group.yaml")))
  environment           = yamldecode(file(find_in_parent_folders("environment.yaml", local.default_yaml_path)))
}

#Templatize the provider generator so it can be used for different providers
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "azurerm" {
  features {}
  subscription_id = "${local.subscription.subscription_id}"
}
EOF
}

remote_state {
  backend = "azurerm"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    subscription_id      = local.subscription.state_subscription
    resource_group_name  = local.subscription.state_resource_group
    storage_account_name = local.subscription.state_storage_account
    container_name       = "terraform-state"
    key                  = "${path_relative_to_include()}/terraform.tfstate"
  }
}

inputs = merge(
    local.org,
    local.subscription,
    local.resource_group,
    local.environment
)