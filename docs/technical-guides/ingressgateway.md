# Configuring Istio IngressGatway with Let's Encrypt Certificate

Now let's jump into the interesting bit. Let's create a sample nginx deployment and expose it through Istio Ingressgateway over TLS. 

## DNS changes

Determine the public IP address of istio-ingressgateway load balancer

```
kubectl get service istio-ingressgateway -n istio-system
```

```
NAME                   TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)                                      AGE
istio-ingressgateway   LoadBalancer   10.0.41.165   4.250.87.120   15021:32693/TCP,80:32134/TCP,443:32131/TCP   8d
```

Point the domain to the external IP address. In our case, we have pointed both kubeflex.co.uk and www.kubeflex.co.uk to 4.250.87.120. 

## Create a test deployment
In our case, we have exposed our frontend service through the ingressgateway. But for simplicity, let's expose an nginx deployment through the ingressgateway. 

Directory structure
```
clusters
--production
----frontend
------deployment.yaml
------service.yaml
------namespace.yaml
------service-account.yaml
```
Content of namespace.yaml

```
apiVersion: v1
kind: Namespace
metadata:
  name: frontend
  labels:
    istio-injection: enabled
```

Note that, we have enabled istio-injection in this namespace as the traffic in and out of this namespace matter to us. 
Also it is important to create service accounts for each application as it provides an identity for the pods in the service mesh. 

Content of service-account.yaml
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: frontend
  namespace: frontend
```

Content of deployment.yaml

```
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: nginx
  name: frontend
  namespace: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: nginx
    spec:
      containers:
      serviceAccountName: frontend
      - image: nginx
        name: nginx
        resources: {}
status: {}
```

Content of service.yaml
```
apiVersion: v1
kind: Service
metadata:
  labels:
    app: nginx
  name: frontend
  namespace: frontend
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx
  type: ClusterIP
```

Merge above changes to the main branch of the cluster-config repository. FluxCD will do the deployment. 

## Istio Configuration

Now we need to create a gateway resource which describes how the load balancer at the edge of the mesh handles incoming traffic. 

Directory structure
```
clusters
--production
----istio-system
------gateway.yaml
```

Content of gateway.yaml
```
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - '*'
```
For now, we are allowing HTTP traffic until we create the certificate using Let's Encrypt CRDs. 

In addition to that, we need a Virtual Service, which describes how the traffic is routed. 

Directory structure
```
clusters
--production
----istio-system
------gateway.yaml
------virtual-service.yaml
```
Content of virtual-service.yaml
```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: frontend
  namespace: istio-system
spec:
  hosts:
    - "www.kubeflex.co.uk"
    - "kubeflex.co.uk"
  gateways:
    - gateway
  http:
    - route:
        - destination:
            host: frontend.frontend.svc.cluster.local
            port:
              number: 80
```
This routes the traffic receives by the gateway to the frontend service if the host maches with the above specification. 

Merge the above changes, so that FluxCD can do the deployment. Once the deployment is done, we are able to access the deployment via http://kubeflex.co.uk endpoint. 

## Let's Encrypt TLS Certificate

Now let's create a certificate resource. 

Directory structure
```
clusters
--production
----istio-system
------certificate.yaml
```
Content of certificate.yaml
```
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: kubeflex
  namespace: istio-system
spec:
  secretName: kubeflex-tls
  duration: 2160h # 90d
  renewBefore: 360h # 15d
  isCA: false
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
  usages:
    - server auth
    - client auth
  dnsNames:
    - "kubeflex.co.uk"
    - "www.kubeflex.co.uk"
  issuerRef:
    name: letsencrypt-prod-cluster
    kind: ClusterIssuer
    group: cert-manager.io
```

Once this is merged, cert-manager will create the certificate and store it in "kubeflex-tls" secret. 

We can see the progress with the following commands

```
kubectl get certificates -A
kubectl get certificaterequets -A
```
Now that we have the certificate, we can modify the gateway resource. 

Content of gateway.yaml
```
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - '*'
    - port:
        number: 443
        name: https
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: kubeflex-tls
      hosts:
      - "www.kubeflex.co.uk"
      - "kubeflex.co.uk"
```


Once the above changes are merged, we are able to access the deployment via https://kubeflex.co.uk or https://www.kubeflex.co.uk
