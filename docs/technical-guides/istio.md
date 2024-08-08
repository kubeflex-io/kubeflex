# Istio

Istio is an open-source service mesh platform that provides a uniform way to connect, manage, and secure microservices. It allows you to connect, secure, control, and observe microservices, regardless of the underlying infrastructure. Istio extends the capabilities of Kubernetes to manage and orchestrate microservices by adding features like traffic management, security, policy enforcement, and telemetry.

Now that we already have configured FluxCD, the installation is fairely easy. 

## Istio-system Namespace

Create a manifest so that FluxCD can create istio-system namespace

```
clusters
--production
----istio-system
------namespace.yaml
```

Content of namespace.yaml
```
apiVersion: v1
kind: Namespace
metadata:
  name: istio-system
```

## Helm Repository
Create a HelmRepository manifest file inside istio-system directory

```
clusters
--production
----istio-system
------namespace.yaml
------helm-istio-repository.yaml
```

Content of helm-istio-repository.yaml
```
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: istio
  namespace: istio-system
spec:
  interval: 5m
  url: https://istio-release.storage.googleapis.com/charts
```
You can generate the above manifest with the following command

```
flux create source helm istio --url=https://istio-release.storage.googleapis.com/charts --interval=10m --namespace istio-system --export
```
## Install Istio Base Chart

To install Istio Base chart, we use HelmRelease CRD as follows

```
clusters
--production
----istio-system
------namespace.yaml
------helm-istio-repository.yaml
------helm-release-istio-base.yaml
```

Content of helm-release-istio-base.yaml
```
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: istio-base
  namespace: istio-system
spec:
  interval: 5m
  chart:
    spec:
      chart: base
      sourceRef:
        kind: HelmRepository
        name: istio
        namespace: istio-system
      interval: 1m
```
You can generate the above manifest with the following command

```
flux create helmrelease istio-base --namespace istio-system --source=HelmRepository/istio --chart=base --export
```

## Install istiod

Similarly, install istiod

```
clusters
--production
----istio-system
------namespace.yaml
------helm-istio-repository.yaml
------helm-release-istio-base.yaml
------helm-release-istiod.yaml
```

Content of helm-release-istiod.yaml
```
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: istiod
  namespace: istio-system
spec:
  interval: 5m
  dependsOn:
    - name: istio-base
      namespace: istio-system
  chart:
    spec:
      chart: istiod
      sourceRef:
        kind: HelmRepository
        name: istio
      interval: 1m
```
You can generate the above manifest with the following command

```
flux create helmrelease istiod --namespace istio-system --source=HelmRepository/istio --chart=istiod --export
```
## Install istio-ingressgateway
We will configuring the istio-ingressgateway so that we can ingest the external traffic

```
clusters
--production
----istio-system
------namespace.yaml
------helm-istio-repository.yaml
------helm-release-istio-base.yaml
------helm-release-istiod.yaml
------helm-release-istio-gateway.yaml
```

Content of helm-release-istio-gateway.yaml

```
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: istio-ingressgateway
  namespace: istio-system
spec:
  interval: 5m
  dependsOn:
    - name: istio-base
      namespace: istio-system
    - name: istiod
      namespace: istio-system
  chart:
    spec:
      chart: gateway
      sourceRef:
        kind: HelmRepository
        name: istio
        namespace: istio-system
      interval: 1m

```

Now we can commit these and push the changes to the main branch. FluxCD will do the thing. As of now, ingressgateway is still not able to accept the traffic. We will configure this in a later section. 

