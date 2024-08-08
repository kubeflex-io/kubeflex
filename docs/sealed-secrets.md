# Sealed Secrets
Sealed Secrets is a Kubernetes tool that enhances security by enabling the encryption of Kubernetes Secrets at rest in a Git repository. It allows users to commit encrypted versions of their Secrets to source control while still maintaining the ability to decrypt and use them within the Kubernetes cluster. Sealed Secrets employs public-key cryptography, where the cluster holds the public key, enabling it to encrypt Secrets, while a client tool called "kubeseal" uses a private key to decrypt the Secrets for use within the cluster. This approach ensures that sensitive information, such as passwords or API keys, remains secure even when stored in version control.

## Helm Repository
Let's create a HelmRepository for sealed-secrets
Directory structure
```
clusters
--production
----flux-system
----kustomization.yaml
------helmrepositories
--------sealed-secrets.yaml
```

The content of sealed-secrets.yaml
```
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: sealed-secrets
  namespace: flux-system
spec:
  interval: 1h0m0s
  url: https://bitnami-labs.github.io/sealed-secrets
```
The content of kustomization.yaml
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - gotk-components.yaml
  - gotk-sync.yaml
  - helmrepositories/sealed-secrets.yaml
```

## Creating the namespace
Lets create a namespace for sealed-secrets

Directory structure
```
clusters
---production
-----sealed-secrets
-------namespace.yaml
```
Content of namespace.yaml
```
apiVersion: v1
kind: Namespace
metadata:
  name: sealed-secrets
```
Note, we do not want to inject istio sidecar for this namespace. 

## Creating the helmrelease

Let's deploy sealed-secrets using a helmrelease CRD
Directory structure
```
clusters
--production
----sealed-secrets
------namespace.yaml
------sealed-secrets.yaml
```

Content of sealed-secrets.yaml
```
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: sealed-secrets
  namespace: flux-system
spec:
  chart:
    spec:
      chart: sealed-secrets
      sourceRef:
        kind: HelmRepository
        name: sealed-secrets
      version: ">=1.15.0-0"
  interval: 1h0m0s
  releaseName: sealed-secrets-controller
  targetNamespace: sealed-secrets
  install:
    crds: Create
  upgrade:
    crds: CreateReplace
```

Push the above changes to the main branch of cluster-config repository and FluxCD will automatically do the sealed-secrets deployment

## Validation

Let's validate what we have done by creating an encrypted secret. 

### Create a namespace. 
Folder structure
```
clusters
--production
----test-namespace
------namespace.yaml
```
Content of namespace.yaml

```
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace
```
### Create a secret
Create a secret in the test-namespace as follows
```
clusters
--production
----test-namespace
------namespace.yaml
------secret.yaml
```

Generate the content of secret.yaml as follows
```
kubectl create secret generic test-secret -n test-namespace --from-literal=password=password123 --dry-run=client -o yaml > secret.yaml
```

The content of secret.yaml
```
apiVersion: v1
data:
  password: cGFzc3dvcmQxMjM=
kind: Secret
metadata:
  creationTimestamp: null
  name: test-secret
  namespace: test-namespace
```

As you can see, the password value is base64 encoded, not encrypted. If we commit this file into the repository, anyone who has the access to the repository would be able to decode the secret as follows
```
echo -n "cGFzc3dvcmQxMjM=" |base64 -d
```
### Retrieving the public certificate
In order to encrypt the secrets, we need to install kubeseal utility. You can see the latest releases [here](https://github.com/bitnami-labs/sealed-secrets/tags)

Now, retrieve the public certificate with kubeseal utility. Please note that the controller name depends on the helmrelease name. 
```
kubeseal --controller-name=sealed-secrets-controller --controller-namespace=sealed-secrets --fetch-cert > pub.crt
```
Now that we have the public key, we can encrypt our secret.yaml

```
kubeseal -o yaml --scope cluster-wide --cert pub.crt < secret.yaml > secret-enc.yaml
```
This will write the encrypted secret into secret-enc.yaml. 

Let's inspect the content

```
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  annotations:
    sealedsecrets.bitnami.com/cluster-wide: "true"
  creationTimestamp: null
  name: test-secret
  namespace: test-namespace
spec:
  encryptedData:
    password: AgCrjD2fIvmCiOecKrCgdJxXoev2F4P5AbR+weqb7CdrCo+b0SfBHA/aCDnVbjF4GoJqcQk3xGUlHfNsbw7i0zVB5RxhCNziHwRyGI22rghjt6Wj7T04ko3U+YMJalYpM8MFk2Uy34abE08ygFzE491/XAy4Yym1hQEQAANu8iXH59r+3xOG+UhqycXYatJlstQnq51/7JQZ3+DbC54C6z6JereLv8EZmIXjiJ682jY/cA3clMoYWdksng/rAVQlJwgG7oRtJUFWAGhTiBMO4PBh5CDdQrcSpMUbEOYJDxewcFUswDZlWWA8h895wjnGdy0oRWc/+kOCt1Tm2KKKIPH2/y/HBcFTu5yw+nStQ+HKam0lZNF4i+uC18FSLP0RJp/VEsWXtBZlttluRCJQgy3l7wdc3EOtw0S5XAIq4KZaSFyTKRL56iiXZYxIrsBqhDCmxDxnUxoM2E7RjWBPziOPCogoWO+FsEX7HL0AC2+kj3K7nBJ6vWkfxXoitrItIfnDfkEoU9PlQVeqH8rv0JaKYcNqFlMQJBQdSJUsolEP7lU1IMGUcwDZwnSUwAMIH+fRqv+HD4AqgWMkb2v/PWKy1Oi728LterGrs9xtp1X9QuKF/yeZT7lxhdbNp3kIq9CLqDUGG/ifWKb/ovEUpXEItIbXKg+VYJHQ9lk6/gr7kOf5qWYz6xfy4jAae5ZjSFuel4k3qsbDA==
  template:
    metadata:
      annotations:
        sealedsecrets.bitnami.com/cluster-wide: "true"
      creationTimestamp: null
      name: test-secret
      namespace: test-namespace
```

As you can see, the password now has been encrypted. 

Now we can safely commit secret-enc.yaml file to the repository. Kubernetes would be able to decrypt this secret as it already has sealed-secrets private key. 

### Decrpting the secret

Once the changes are merged, FluxCD will create the secret in the kubernetes cluster. Now we can inspect the secret using kubectl utility

```
kubectl get secret test-secret -n test-namespace -o yaml
```

Output will be similar to the following. 

```
apiVersion: v1
data:
  password: cGFzc3dvcmQxMjM=
kind: Secret
metadata:
  creationTimestamp: null
  name: test-secret
  namespace: test-namespace
```
We can observe that Kubernetes was able to decrypt the secret. 
