# Cloud & Containers Live Demo Script

## Table Of Contents

- [Setup](#setup)
- [Pre Demo](#pre-demo)
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

## Serverless with Teleport


### VM Comparison

- Baseline Azure CLI

```sh
# nothing up our sleeves
time docker images

# 931 MB - 11 layers
time docker run --rm demo42t.azurecr.io/base-artifacts/azure-cli:2.0.75 echo 'hello planet vm'
```

### Orca

- View the Yaml - in VS Code

- Teleport with Orca
  ```sh
  az acr run -f acr-task.yaml /dev/null
  ```
