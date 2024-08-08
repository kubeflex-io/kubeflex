# Request Authentication with Istio and Keycloak

RequestAuthentication defines what request request authentication methods are supported by a workload. Please see [this](https://istio.io/latest/docs/reference/config/security/request_authentication/)

## Scenairio 
Let's assume we have a service called skills-service which as two basic endpoints. This is deployed in skills-service namespace. 
```
/addskill - This adds an skill to the database
/getskills - This retrieves all the skills in the database.
```

We have following configuration in our [keycloak deployment](docs/keycloak.md) deployment. 

**Realm name**: istio

**Roles**: admin, user

**Users**: skill-admin, skill-user

**Role assignments**:

The role "user" has been assigned to "skill-user" user. 

THe role "admin" has been assigned to "skill-admin" user. 


## RequestAuthorization

Directory structure
```
clusters
--production
----skills-service
-------deployment.yaml
-------service.yaml
-------service-account.yaml
-------namespace.yaml
-------request-authentication.yaml
```

Request Authentication manifest
```
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: skills-service-request-authentication
  namespace: skills-service
spec:
  selector:
     matchLabels:
      app: skills-service
  jwtRules:
   - issuer: "https://keycloak.kubeflex.co.uk/realms/istio"
     jwksUri: "https://keycloak.kubeflex.co.uk/realms/istio/protocol/openid-connect/certs"
     outputPayloadToHeader: jwt-parsed
```

This will reject a request if the request contains invalid authentication information. However, a request which does not have any authentication information at all, will be accepted. To prevent this, we need to have an Authorization Policy.

Directory structure
```
clusters
--production
----skills-service
-------deployment.yaml
-------service.yaml
-------service-account.yaml
-------namespace.yaml
-------request-authentication.yaml
-------authorization-policy.yaml
```
authorization-policy.yaml
```
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: skills-service-authorization-policy
  namespace: skills-service
spec:
  selector:
    matchLabels:
      app: skills-service
  rules:
  - from:
    - source:
        requestPrincipals: ["*"]
```

Above configuration makes the authentication mandatory to call both /getskills and /addskill endpoints. However, with the current configuration, both "skill-user" and "skill-admin" can add skills. Let's change the authorization policy such a way that, only admin user can add skills. 

authorization-policy.yaml
```
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: skills-service-authorization-policy
  namespace: skills-service
spec:
  selector:
    matchLabels:
       app: skills-service
  rules:
  - from:
    - source:
        requestPrincipals: ["*"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/getskills"]

  - from:
    - source:
        requestPrincipals: ["*"]
    to:
    - operation:
        methods: ["POST"]
        paths: ["/addskill*"]
    when:
    - key: request.auth.claims[realm_access][roles]
      values: ["admin"]
```
