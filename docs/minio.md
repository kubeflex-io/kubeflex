# MinIO Deployment
MinIO is a high-performance, S3 compatible object store. This gives us the flexibility to move our object storage to any cloud provider in the future. 

## Helm Repository

Directory structure
```
clusters
--production
----flux-system
------helm-repositories
--------bitnami.yaml
------kustomization.yaml
```
Content of bitnami.yaml
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

Content of kustomisation.yaml
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - gotk-components.yaml
  - gotk-sync.yaml
  - helmrepositories/sealed-secrets.yaml
  - helmrepositories/cert-manager.yaml
  - helmrepositories/bitnami.yaml

```

## Deploying MinIO

Directory structure
```
clusters
--production
----minio
------minio.yaml
------namespace.yaml
------secret-enc.yaml
------service-account.yaml
```

Content of minio.yaml
```
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: minio
  namespace: minio
spec:
  chart:
    spec:
      chart: minio
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        name: bitnami
        namespace: flux-system
      version: 14.1.4
  interval: 1m0s
  timeout: 20m
  targetNamespace: minio
  values:
    auth:
      existingSecret: minio
    defaultBuckets: "kubeflex"
    resources:
      limits:
      requests:
        cpu: 10m
        memory: 40Mi
    serviceAccount: 
      create: false
      name: "minio"
```
Content of namespace.yaml
```
apiVersion: v1
kind: Namespace
metadata:
  name: minio
  labels:
    istio-injection: enabled

```
Content of service-account.yaml
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: minio
  namespace: minio
```

Content of secret-enc.yaml
```
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  annotations:
    sealedsecrets.bitnami.com/cluster-wide: "true"
  creationTimestamp: null
  name: minio
  namespace: minio
spec:
  encryptedData:
    root-password: <enc>
    root-user: <enc>
  template:
    metadata:
      annotations:
        sealedsecrets.bitnami.com/cluster-wide: "true"
      creationTimestamp: null
      name: minio
      namespace: minio

```

Please note that the secret has been encrypted using sealed-secrets. Please see [here](sealed-secrets.md). 
It is important to note that, we need to have root-password and root-user as keys in the secret. 

Once the above files are pushed to the main branch, FluxCD will deploy MinIO. Please note that if we want high availability feature, the deployment will be a little different. 
