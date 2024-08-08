# FluxCD Installation

[FluxCD](https://fluxcd.io/) is a continuous delivery tool that automates the deployment and lifecycle management of applications on Kubernetes. It uses GitOps principles to synchronize application code stored in Git repositories with Kubernetes clusters, ensuring consistency and reliability in the deployment process. 

## Installation Steps

1. Install Flux CLI

```
curl -s https://fluxcd.io/install.sh | sudo bash
```
2. Create a GitHub Personal Access Token
Flux bootstrap command needs a PAT to access GitHub API. 
Click on profile -> Settings -> Developer Settings and create a Classic Personal Access Token.
And then export the token as an environment variable
```
export GITHUB_TOKEN=<gh-token>
```
3. Bootstrap Flux

```
flux bootstrap github \
  --token-auth \
  --owner=kubeflex \
  --repository=paas-config \
  --branch=main \
  --path=clusters/production \
  --personal
```
With this, paas-config GH repository in kubeflex organization will be initialized. 

After this is done, you would be able to see the following files in the new repository

```
clusters
-- production
----flux-system
------gotk-components.yaml
------gotk-sync.yaml
------kustomization.yaml
```

Now we can start deploying resources into the Kubernetes cluster by pushing the changes to this github repository. Also please see the [docs](release.md) to learn how flux contributes to our automated release process. 

## Configuring notifications
It is helpful to receive notifications on the status of our GitOps pipelines. For this we make use of [Flux Notification Controller](https://fluxcd.io/flux/components/notification/) to send notifications to our slack. 

1. Create a slack channel. E.g. #flux-notifications
2. Create a new slack application by visiting [this](https://api.slack.com/apps). Give it an appropriate name. E.g.: FluxCD
3. Navigate to Oauth & Permissions section in the slack app and provide channels:read, chat:write, chat:write.customize permissions.
4. Install the slack app to the slack workspace and note down Bot User Oauth Token.
5. Install the application to #flux-notifications channel.
6. Create a secret in flux-system namespace with the above Bot User Oauth Token

Directory Structure
```
clusters
--production
----flux-system
------slack-secret-enc.yaml
```
Content
```
apiVersion: v1
data:
  token: <token>
kind: Secret
metadata:
  name: slack-secret
  namespace: flux-system
type: Opaque
```
Make sure to encrypt the secret using [sealed-secrets](sealed-secrets.md)

7. Create slack provider
Directory structure
```
clusters
--production
----flux-system
------slack-secret-enc.yaml
------notification-provider-slack.yaml
```

Content
```
---
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Provider
metadata:
  name: notification-provider-slack
  namespace: flux-system
spec:
  address: https://slack.com/api/chat.postMessage
  channel: flux-notifications
  secretRef:
    name: slack-secret
  type: slack
  username: FluxCD
```
8. Create Alert resource to specify on which events we would like to get notified

Directory structure
```
clusters
--production
----flux-system
------slack-secret-enc.yaml
------notification-provider-slack.yaml
------notification-alert-slack.yaml
```
Content
```
---
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Alert
metadata:
  name: notification-alert-slack
  namespace: flux-system
spec:
  eventSeverity: info
  eventSources:
  - kind: Kustomization
    name: '*'
  - kind: GitRepository
    name: '*'
  - kind: HelmChart
    name: '*'
  - kind: HelmRepository
    name: '*'
  - kind: HelmRelease
    name: '*'
  - kind: ImageRepository
    name: '*'
  - kind: ImagePolicy
    name: '*'
  - kind: ImageUpdateAutomation
    name: '*'
  providerRef:
    name: notification-provider-slack
```
That would be it. Now we should be able to see Flux notifications in #flux-notifications slack channel

![Alt text](../images/flux-notifications.png?raw=true "Flux Notifications")
