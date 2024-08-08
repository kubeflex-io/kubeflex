# Helm Repositores
In FluxCD, HelmRepositories is a custom resource definition (CRD) used to manage Helm repositories. Helm repositories are collections of Helm charts, which are packages of pre-configured Kubernetes resources. By defining a Helm repository using HelmRepositories, FluxCD can access and sync Helm charts from that repository into your Kubernetes cluster.

## Bitnami Helm Repository

Let's create a Helm Repository for Bitnami. They have comprehensive suite of helm charts like MySQL, Keycloak etc. 

Directory Structure of paas-config repository

```
clusters
--production
----flux-system
------gotk-components.yaml
------gotk-sync.yaml
------kustomization.yaml
------helmrepositories
--------bitnami.yaml
```

Contenat of bitnami.yaml
```
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: bitnami
  namespace: flux-system
spec:
  interval: 1h0m0s
  url: https://charts.bitnami.com/bitnami
```
You can use the following command to generate the above manifest. 
```
flux create source helm bitnami --url=https://charts.bitnami.com/bitnami --interval=10m --export
```

As you can see we have kustomization.yaml file inside flux-system directory. (which was created during the bootstrap). This file helps kuztomisation controller to build the content. We need to modify that too to include our new file. 

Content of kustomization.yaml
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - gotk-components.yaml
  - gotk-sync.yaml
  - helmrepositories/bitnami.yaml
```

Now commit these changes and push it to the main branch. FluxCD will automatically create the resources for you. 
You can use the following commands to view the progress. 

```
kubectl get helmrepositories -n flux-system
```
We can also see kustomize controller logs to see the progress. 

```
kubectl get pods -n flux-system
NAME                                       READY   STATUS    RESTARTS   AGE
helm-controller-74b9b95b88-hc6rx           1/1     Running   0          7d18h
kustomize-controller-696657b79c-fwlp9      1/1     Running   0          7d18h
notification-controller-6cb7b4f4bf-z4f7w   1/1     Running   0          7d18h
source-controller-5c69c74b57-6n47k         1/1     Running   0          7d18h
```
Now we can see the logs. 
```
kubectl logs -f kustomize-controller-696657b79c-fwlp9 -n flux-system
```

