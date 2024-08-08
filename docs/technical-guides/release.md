# Conventional Commits, Semantic Versioning and CircleCI

This document describes how we have implemented the release process. This is a combination of following standards/conventions/technologies.
1. Conventional Commits
2. GitHub Actions
3. Semantic Versioning
4. CircleCI
5. FluxCD

## Conventional Commits
Conventional Commits is a specification for structuring commit messages in software development. It defines a set of rules for creating commit messages that convey meaning about the changes made in the commit. This standardization helps in automating versioning, generating changelogs, and facilitating collaboration among developers. See [here](https://www.conventionalcommits.org/en/v1.0.0/)

## Semantic Versioning
Semantic versioning (often abbreviated as SemVer) is a versioning scheme used in software development to convey meaning about the changes in a software application or library. It consists of three numbers separated by periods: MAJOR.MINOR.PATCH. See [here](https://semver.org/)

## The repository

Let's use our bookinfo node repository as the example. We already have package.json file at the root of the repository so that we can track our release version. If this is not a node repository, we can alternatively add a package.json file as follows
```
{
  "name": "bookinfo",
  "version": "1.0.0"
}
```

In order to automate the release creation, we use [release-please](https://github.com/marketplace/actions/release-please-action) GitHub action. Add the following content to .github/workflows/release.yml file. 

```
name: Release

on:
  push:
    branches:
      - main

permissions:
  contents: write
  pull-requests: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '21'

      - name: Create Release
        uses: google-github-actions/release-please-action@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          release-type: node
```
So, this GitHub action does the following things. 
1. Versioning: It determines the next version number based on the changes introduced in the pull requests since the last release. It follows Semantic Versioning rules to increment the version number accordingly (major, minor, or patch).
2. Release Notes: It generates release notes by compiling the descriptions of pull requests merged since the last release. These release notes provide a summary of the changes included in the release, helping users understand what has been added, changed, or fixed.
3. GitHub Release: It creates a new release on GitHub with the calculated version number and the generated release notes. This automates the process of creating releases and ensures consistency across releases.

Commit the above change with the following commit message, so that it will be picked up as a minor release. 
```
feat: release process
```

Once the above change is pushed into the main branch, release please will create a new PR to bump the version. 
![Alt text](../images/release-please-pr.png?raw=true "Pull Request")

Once the PR is merged, it will create a new release with the version v1.0.0.

![Alt text](../images/release-please-version.png?raw=true "Version")

Now, from this point onwards, release-please will honor our commit messages and it will create pull requests to bump the release version accordingly. 

## Image creation with CircleCI

Now we would like CircleCI to create images whenever a GitHub release is created. And also we would like to tag the image with the release version and push that into the image repository. 
Add the following content to .circleci/config.yml file
```
version: 2.1

jobs:
  build-and-push:
    docker:
      - image: cimg/node:21.7.1
    steps:
      - setup_remote_docker
      - checkout
      - run:
          name: Login to Azure Container Registry
          command: docker login -u $AZURE_ACR_USERNAME -p $AZURE_ACR_PASSWORD $AZURE_ACR_LOGIN_SERVER
      - run:
          name: Build Docker image
          command: |
            docker build -t $CIRCLE_PROJECT_REPONAME .
      - run:
          name: Tag Docker image
          command: |
            docker tag $CIRCLE_PROJECT_REPONAME $AZURE_ACR_LOGIN_SERVER/$CIRCLE_PROJECT_REPONAME:$CIRCLE_TAG
      - run:
          name: Push Docker image to Azure Container Registry
          command: |
            docker push $AZURE_ACR_LOGIN_SERVER/$CIRCLE_PROJECT_REPONAME:$CIRCLE_TAG

workflows:
  version: 2
  build-and-push-image:
    jobs:
      - build-and-push:
          context:
            - registry
          filters:
            branches:
              ignore: /.*/
            tags:
              only: /^v.*/
```
So, this instructs CircleCI to build and push the image to our container registry, whenever a release is created. Please see CircleCI [docs](https://circleci.com/docs/variables/) to learn more about CircleCI built-in variable CIRCLE_TAG.

![Alt text](../images/circleci-build-output.png?raw=true "Build Output")

## FluxCD image reflector and automation controllers

Now, at this point we already have the image in our image repository. At the same time, we already have configured FluxCD so that it reconcile the changes whenever we modify the manifests in paas-cluster repository. 
Below is the respective manifest for our bookinfo application. 
Content of deployment.yaml
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bookinfo
  namespace: bookinfo
  labels:
    app: bookinfo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bookinfo
  template:
    metadata:
      labels:
        app: bookinfo
        sidecar.istio.io/inject: "true"
    spec:
      serviceAccountName: bookinfo
      automountServiceAccountToken: true
      containers:
        - name: bookinfo
          image: acr.kubeflex.co.uk/bookinfo:v1.0.0 
          env:
            - name: DB_HOST
              value: "bookinfo-db.bookinfo.svc.cluster.local"
```
However, we need to manually modify the version of the image to get FluxCD to pick the changes. We can automate this by using FluxCD image reflector and automation controllers. 
Inspect the controllers we have installed at this point. See [here](fluxcd.md) for the initial bootstrap steps. 
```
kubectl get deployments -n flux-system
NAME                          READY   UP-TO-DATE   AVAILABLE   AGE
helm-controller               1/1     1            1           43d
kustomize-controller          1/1     1            1           43d
notification-controller       1/1     1            1           43d
source-controller             1/1     1            1           43d
```
Now we need to install image automation controller and image reflector controller. We can use the same bootstrap command with an additional argument as follows
```
flux bootstrap github \
  --token-auth \
  --owner=kubeflex \
  --repository=paas-config \
  --branch=main \
  --path=clusters/production \
  --personal
  --components-extra="image-reflector-controller,image-automation-controller"
```
Verify that the controllers have been installed. 
```
kubectl get deployments -n flux-system
NAME                          READY   UP-TO-DATE   AVAILABLE   AGE
helm-controller               1/1     1            1           43d
image-automation-controller   1/1     1            1           38h
image-reflector-controller    1/1     1            1           38h
kustomize-controller          1/1     1            1           43d
notification-controller       1/1     1            1           43d
source-controller             1/1     1            1           43d
```
Create an image repository manifest to scan and store a specific set of tags in a database. 
Directory structure
```
clusters
--production
----flux-system
------imagerepositories
--------bookinfo.yaml
```
Content
```
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: bookinfo
  namespace: flux-system
spec:
  secretRef:
    name: acr-secret
  image: acr.kubeflex.co.uk/bookinfo
  interval: 5m
```

Now let's create an imagepolicy resource which defines rules for selecting a latest image from ImageRepositories. 
Directory structure
```
clusters
--production
----flux-system
------imagerepositories
--------bookinfo.yaml
------imagepolicies
--------bookinfo.yaml
```
Content
```
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: bookinfo
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: bookinfo
  policy:
    semver:
      range: '>=1.0.0'
```
Next, let's define ImageUpdateAutomation resource which defines an automation process that will update a git repository, based on image policy objects in the same namespace. 
Directory structure
```
clusters
--production
----flux-system
------imagerepositories
--------bookinfo.yaml
------imagepolicies
--------bookinfo.yaml
----image-update-automation.yaml
```
Content
```
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 30m
  sourceRef:
    kind: GitRepository
    name: flux-system
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        email: fluxcdbot@users.noreply.github.com
        name: fluxcdbot
      messageTemplate: '{{range .Updated.Images}}{{println .}}{{end}}'
    push:
      branch: main
  update:
    path: ./clusters/production
    strategy: Setters
```
See the [docs](https://fluxcd.io/flux/components/image/imageupdateautomations/)

Finally we need to specify which specific location FluxCD should modify whenever a new image is available in remote image repository. We can do this by adding a comment to the deployment manifest. 
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bookinfo
  namespace: bookinfo
  labels:
    app: bookinfo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bookinfo
  template:
    metadata:
      labels:
        app: bookinfo
        sidecar.istio.io/inject: "true"
    spec:
      serviceAccountName: bookinfo
      automountServiceAccountToken: true
      containers:
        - name: bookinfo
          image: eocontainerregistry.azurecr.io/bookinfo:v1.1.1 # {"$imagepolicy": "flux-system:bookinfo"}
          env:
            - name: DB_HOST
```

Now, whenever a new image is pushed to the image repository, fluxcd will modify the image tag in the deployment manifest. This change will again reconciled by FluxCD and a new deployment will happen as part of Flux reconciliation process. 
