# Cert Manager
Cert manager is a Kubernetes native certificate management controller. It can automatically provision, manage and renew TLS certificates from various certificate authorities (CA). We have configured cert-manager to obtain Let's encrypt certificates for our public endpoints. 

## Helm Repository

Directory structure
```
clusters
--production
----flux-system
------helm-repositories
--------cert-manager.yaml
------kustomization.yaml
```

Content of cert-manager.yaml

```
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: cert-manager
  namespace: flux-system
spec:
  interval: 1h0m0s
  url: https://charts.jetstack.io

```
Content of kustomization.yaml
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - gotk-components.yaml
  - gotk-sync.yaml
  - helmrepositories/cert-manager.yaml
```

## Namespace

Let's create a namespace for cert-manager deployment

Directory structure
```
clusters
--production
----cert-manager
------namespace.yaml
```
Content of namespace.yaml
```
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager

```
Note: We do not want to inject istio sidecar to this namespace. 

## Helmrelease
Let's deploy cert-manager with helmrelease CRD

Directory structure
```

clusters
--production
----cert-manager
------namespace.yaml
------cert-manager.yaml
```

Content of cert-manager.yaml
```
---
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: cert-manager
  namespace: flux-system
spec:
  chart:
    spec:
      chart: cert-manager
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        name: cert-manager
        namespace: flux-system
      version: 1.14.4
  interval: 1m0s
  releaseName: cert-manager
  targetNamespace: cert-manager
  values:
    installCRDs: true
```

Once the above changes are merged, FluxCD will deploy cert-manager on cert-manager namespace. 

## Cluster Issuers

We need to configure which CA (Certificate Authorities) cert-manager can work with. Let's create two cluster issuer manifests for both Let's encrypt production CA and Staging CA

Directory structure
```
clusters
--production
----istio-system
------prod-cluster-issuer.yaml
------staging-cluster-issuer.yaml
```

These are cluster wide resources. 

Content of prod-cluster-issuer.yaml
```
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod-cluster
  namespace: istio-system
spec:
  acme:
    email: ranatunga@kubeflex.co.uk
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-cluster
    solvers:
    - http01:
        ingress:
          class: istio

```

Content of staging-cluster-issuer.yaml
```
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging-cluster
  namespace: istio-system
spec:
  acme:
    email: ranatunga@kubeflex.co.uk
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-staging-cluster
    solvers:
    - http01:
        ingress:
          class: istio

```
With this, we are ready to obtain certificates for our public endpoints. We will discuss this in a later section. 
