# Monitoring Tools

Monitoring Tools Installation:
While this could have been done with a more systematic approach using HelmReleases, we have chosen to install monitoring tools such as Prometheus, Grafana, Kiali, and Jaeger using plain Kubernetes manifests that come with the Istio installation package for the sake of expediency.

## Installation

Directory structure
```
clusters
--production
----istio-system
------kiali.yaml
------prometheus.yaml
------grafana.yaml
------jaeger.yaml
```

Download the manifests:

```
https://raw.githubusercontent.com/istio/istio/release-1.21/samples/addons/grafana.yaml
https://raw.githubusercontent.com/istio/istio/release-1.21/samples/addons/jaeger.yaml
https://raw.githubusercontent.com/istio/istio/release-1.21/samples/addons/kiali.yaml
https://raw.githubusercontent.com/istio/istio/release-1.21/samples/addons/prometheus.yaml
```
Currently we access these ClusterIP services with port-forwarding. 
We intend to convert these deployments into helmreleases soon. 
