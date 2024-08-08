# CircleCI

Let's take a look at our deployment cicle. 
1. We do code changes on a feature branch and that branch is merged to the main branch.
2. CircleCI kicks in and creates a container image.
3. CircleCI pushes the image into Azure container registry
4. We note down the image tag and update the corresponding kubernetes deployment manifest in the paas-config repository.
5. FluxCD kicks in and update the corresponding kubernetes deployment.

Note: We are planning to use Image Reflector Controller and Image Automation Controller to automate this further. 

Let's take a look at how we have configured CircleCI. This is a minimalistic configuration. We are planning to improve the setup with Orbs later on. 

## Service Repository Configuration

We have the following config.yml in each of our repositories. 

Directory structure
```
.circleci
--config.yml
```

Content of .config.yml
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
            docker tag $CIRCLE_PROJECT_REPONAME $AZURE_ACR_LOGIN_SERVER/$CIRCLE_PROJECT_REPONAME:$CIRCLE_SHA1
      - run:
          name: Push Docker image to Azure Container Registry
          command: |
            docker push $AZURE_ACR_LOGIN_SERVER/$CIRCLE_PROJECT_REPONAME:$CIRCLE_SHA1

workflows:
  build-and-push-image:
    jobs:
      - build-and-push:
          context:
            - registry
          filters:
            branches:
              only:
                - main
```
Above environment variables comes from CircleCI context called "registry". 

## CircleCI Configuration

![Alt text](../images/circleci.png?raw=true "Context")
Where

1. **AZURE_ACR_USERNAME** is the username of Azure Container Registry
2. **AZURE_ACR_PASSWORD** is the password of Azure Container Registry
3. **AZURE_ACR_LOGIN_SERVER** is the Azure Container Registry
4. **CIRCLE_PROJECT_REPONAME** is a built-in environment variable. This is the name of the repository of the current project.
5. **CIRCLE_SHA1** is a built-in environment variable. This is the SHA1 hash of the last commit of the current build

## Notes

Please note that we changed our release process later to use semantic versioning. See the [docs](release.md)
