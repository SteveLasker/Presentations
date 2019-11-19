# Cloud & Containers Live Demo Script

## Table Of Contents

- [Setup](#setup)
- [Pre Demo](#pre-demo)
- [Demos](#demos)
- [Serverless with Teleport](#serverless-with-teleport)
- [Short Demo](#short-demo)

## Setup

- Import Env Vars

```sh
export ACR_NAME=demo42t
export LOCATION=soutchcentralus
export RESOURCE_GROUP=$ACR_NAME
```

## Pre Demo

The following is needed to start the demo:

- SSH into the Docker VM

  ```sh
  ssh stevelas@stevelasteleportvm.southcentralus.cloudapp.azure.com
  PS1='$ '
  ```

- ACR Login

  ```sh
  az login
  az acr login -n $ACR_NAME
  az configure --defaults acr=$ACR_NAME
  ```

- Docker Login

  ```sh
  ACR_NAME=${ACR_NAME}
  ACR_USER=${ACR_NAME}
  ACR_PWD="$(az acr credential show -n ${ACR_NAME} --query passwords[0].value -o tsv)"
  ```

- Clear any images

  ```sh
  docker rm -f $(docker ps -a -q)
  docker rmi $(docker images -a -q)
  docker ps -a
  docker images -a
  ```

## Demos

### Serverless with Teleport

#### VM Comparison

- Baseline Azure CLI

```sh
# nothing up our sleeves
time docker images

# 931 MB - 11 layers
time docker run --rm demo42t.azurecr.io/base-artifacts/azure-cli:2.0.75 echo 'hello planet vm'
```
- Review Container Pull Slides

### Orca

- View the Yaml - in VS Code

- Teleport with Orca
  ```sh
  az acr run -f acr-task.yaml /dev/null
  ```

## Base Image Updates

### Baseline

- Change `server.js`
- Watch Automated Build
- Change Server
- Browse http://104.214.72.98/

- Watch task changes

  ```sh
  watch -n1 az acr task list-runs
  ```

- Make a base image chage

  - Change the background color from white to DeepSkyBlue
    Edit: https://github.com/demo42/node-upstream/blob/master/Dockerfile

    ```sh
    FROM node:9-alpine
    ENV NODE_VERSION 9.1-alpine
    ENV BACKGROUND_COLOR DeepSkyBlue
    ```

- Stream logs
  Open a 2nd bash window

  ```sh
  az acr task logs
  ```
- Wait for the change to trickle through

- Show a blocked update
  - Change the background color from white to Red

    ```sh
    FROM node:9-alpine
    ENV NODE_VERSION 9.1-alpine
    ENV BACKGROUND_COLOR red
    ```
