# Deploying Kubernetes Cluster on Azure Cloud

This [directory](https://github.com/kubeflex-io/kubeflex/tree/main/kubernetes) contains the concise code sample illustrating our deployment of Kubernetes on Azure, leveraging Terragrunt to maintain the Don't Repeat Yourself (DRY) principle in our codebase

### Storing States
Before we proceed with creating the resources with terragrunt, we need to create a storange account manually to store the terraform states. 

```
az group create --name terraform-state --location westus
az storage account create --name exoffenderstfstate --resource-group terraform-state
```

### Container Registry
We've set up an [Azure Container Registry (ACR)](subscriptions/azure-sponsorship/resource-groups/production/container-registry/container-registry.tf) alongside our Kubernetes Cluster. To maintain cloud-agnosticism, we're using [private registry authentication](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/) instead of Azure IAM for Kubernetes authentication with the Registry.
