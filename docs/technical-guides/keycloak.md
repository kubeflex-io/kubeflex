# Keycloak Deployment

Keycloak is an open-source identity and access management solution that enables secure authentication, authorization, and single sign-on for web applications and services. This document describes how we have deployed keycloak on kubernetes cluster and how we can expose it via Istio ingressgateway. Ideally this should sit inside the cluster with no public access. 
It is possible that we may have overlooked some of the best practices during this deployment. We highly appreciate your feedback on this. 

## Create namespaces and SAs

As usual, Let's create two namespaces. One for the keycloak database, and the other one for the keycloak deployment. We thought of deploying the database in a separate namespace so that we can better visualize the traffic. 

Directory structure
```
clusters
--production
----keycloak
------namespace.yaml
------service-account.yaml
----keycloakdb
------namespace.yaml
------service-account.yaml
```

Content of keycloak/namespace.yaml
```
apiVersion: v1
kind: Namespace
metadata:
  name: keycloak
  labels:
    istio-injection: enabled

```
Content of keycloak/service-account.yaml
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: keycloak
  namespace: keycloak
```

Content of keycloakdb/namespace.yaml
```
apiVersion: v1
kind: Namespace
metadata:
  name: keycloakdb
  labels:
    istio-injection: enabled

```
Content of keycloakdb/service-account.yaml
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: keycloakdb
  namespace: keycloakdb
```

## Creating Secrets

We need to create secrets for the database (MySQL) root password and database keycloak user password. In addition to that, we needt o create a secret for Keycloak admin user password. Keycloak database user password needs to be created in both the namespaces as secrets cannot be shared. 

Directory structure
```
clusters
--production
----keycloak
------namespace.yaml
------service-account.yaml
------secret-enc.yaml
----keycloakdb
------namespace.yaml
------service-account.yaml
------secret-enc.yaml
```

Content of keycloak/secret-enc.yaml
```
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  annotations:
    sealedsecrets.bitnami.com/cluster-wide: "true"
  creationTimestamp: null
  name: keycloak
  namespace: keycloak
spec:
  encryptedData:
    admin-password: <enc>
    db-password: <enc>
  template:
    metadata:
      annotations:
        sealedsecrets.bitnami.com/cluster-wide: "true"
      creationTimestamp: null
      name: keycloak
      namespace: keycloak
```
Please note that this secret has been encrypted with sealed-secrets. Please see [this](sealed-secrets.md) for more information. 

admin-password would be the admin password of keycloak deployment. db-password is the keycloak database user password. 

Content of keycloakdb/secret-enc.yaml
```
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  annotations:
    sealedsecrets.bitnami.com/cluster-wide: "true"
  creationTimestamp: null
  name: keycloakdb
  namespace: keycloakdb
spec:
  encryptedData:
    mysql-password: <enc>
    mysql-root-password: <enc>
  template:
    metadata:
      annotations:
        sealedsecrets.bitnami.com/cluster-wide: "true"
      creationTimestamp: null
      name: keycloakdb
      namespace: keycloakdb
```

Where mysql-password is the keycloak mysql user password. mysql-root-passowrd is the root password of the MySQL deployment. 

## MySQL Database Deployment
We deploy MySQL using a helmrelease

Directory structure

```
clusters
--production
----keycloak
------namespace.yaml
------service-account.yaml
------secret-enc.yaml
----keycloakdb
------namespace.yaml
------service-account.yaml
------secret-enc.yaml
------database.yaml
```
Content of database.yaml
```
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: keycloakdb
  namespace: keycloakdb
spec:
  chart:
    spec:
      chart: mysql
      reconcileStrategy: ChartVersion
      sourceRef:
        kind: HelmRepository
        name: bitnami
        namespace: flux-system
      version: 10.1.0
  interval: 1m0s
  timeout: 20m
  targetNamespace: keycloakdb
  values:
    auth:
      createDatabase: true
      database: keycloakdb
      username: keycloak-user
      existingSecret: keycloakdb
    serviceAccount:
      name: keycloakdb
      create: false
    image:
      debug: true
```
Note: Ideally, we should mention the resources (limits and requests) in the manifest. 

## Keycloak Deployment

We were not able to find a helm chat which supports MySQL. Currently available charts support only PostgreSQL as the backend. Therefore we go ahead with plain Kubernetes manifest to deploy Keycloak. 

```
clusters
--production
----keycloak
------namespace.yaml
------service-account.yaml
------secret-enc.yaml
------keycloak.yaml
------service.yaml
----keycloakdb
------namespace.yaml
------service-account.yaml
------secret-enc.yaml
------database.yaml
```

Content of keycloak.yaml
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: keycloak
  labels:
    app: keycloak
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      serviceAccountName: keycloak
      automountServiceAccountToken: true
      containers:
        - name: keycloak
          image: quay.io/keycloak/keycloak:20.0.2
          args: ["start"]
          env:
            - name: KEYCLOAK_ADMIN
              value: "admin"
            - name: KEYCLOAK_ADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: keycloak
                  key: admin-password
            - name: KC_HOSTNAME
              value: keycloak.kubeflex.io
            - name: KC_PROXY
              value: "edge"
            - name: KC_DB
              value: mysql
            - name: KC_DB_URL
              value: "jdbc:mysql://keycloakdb-keycloakdb-mysql.keycloakdb.svc.cluster.local:3306/keycloakdb"
            - name: KC_DB_USERNAME
              value: "keycloakapp-user"
            - name: jgroups.dns.query
              value: keycloak
            - name: KC_DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: keycloak
                  key: db-password
          ports:
            - name: http
              containerPort: 8080
            - name: jgroups
              containerPort: 7600

```

Content of service.yaml
```
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: keycloak
  labels:
    app: keycloak
spec:
  ports:
    - name: http
      port: 8080
      targetPort: 8080
  selector:
    app: keycloak
  type: ClusterIP
```

FluxCD can deploy the reources once the changes are merged into the main branch. 


## Keycloak ingress

Now let's create a DNS entry to expose keycloak via ingressgateway. 

Determine the ingressgateway public IP address. 

```
kubectl get service istio-ingressgateway -n istio-system
istio-ingressgateway   LoadBalancer   10.0.41.165   4.250.87.120   15021:32693/TCP,80:32134/TCP,443:32131/TCP   8d
```

Create a DNS entry

keycloak.kubeflex.io -> 4.250.87.120

## Gateway changes

Gateway still serves http on port 80. 

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

Create a virtual service to route the traffic to the keycloak service

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: keycloak
  namespace: istio-system
spec:
  hosts:
    - "keycloak.kubeflex.io"
  gateways:
    - gateway
  http:
    - route:
        - destination:
            host: keycloak.keycloak.svc.cluster.local
            port:
              number: 8080
```

Now we are ready to create the TLS certificate

## Certificate

Create a certificate resource. 

```
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: kubeflex
  namespace: istio-system
spec:
  secretName: keycloak-kubeflex-tls
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
    - "keycloak.kubeflex.io"
  issuerRef:
    name: letsencrypt-prod-cluster
    kind: ClusterIssuer
    group: cert-manager.io
```

Once the above changes are merged, the certificate information will be stored into keycloak-kubeflex-tls secret. 

Let's modify the gateway resource to use the certificate. 

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
        credentialName: keycloak-kubeflex-tls
      hosts:
      - "keycloak.kubeflex.io"
```

With the above change, we can access our keycloak via https://keycloak.kubeflex.io. 
