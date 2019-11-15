# Quick Teleportation Demo

## Table Of Contents

- [Setup](#setup)
- [Pre Demo](#pre-demo)
- [Quick-Quick Demo Time](#quick-quick-demo-time)
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

## Quick-Quick Demo Time


### VM Comparison

- Baseline Azure CLI

```sh
# nothing up our sleeves
time docker images

# 931 MB - 11 layers
time docker run --rm demo42t.azurecr.io/base-artifacts/azure-cli:2.0.75 echo 'hello planet vm'
```

### Orca

- Combined w/task-yaml

  ```sh
  cat acr-task.yaml
  az acr run -f acr-task.yaml /dev/null
  ```
  az acr run \
    --cmd "orca run demo42t.azurecr.io/base-artifacts/azure-cli:2.0.75 echo -e '\e[32m beam me up \e[0m'" /dev/null

## Short Demo

## ACI Comparison

```sh
time az container create \
  --resource-group aci \
  --name az-cli \
  --image ${ACR_NAME}.azurecr.io/base-artifacts/azure-cli:2.0.75  \
  --registry-login-server ${ACR_NAME}.azurecr.io \
  --registry-username $ACR_NAME \
  --registry-password $ACR_PWD \
  --restart-policy Never

az container delete --resource-group aci --name az-cli -y
```

## ACR Tasks, w/Teleport

- Nothing Up Our Sleeve

  ```sh
  az acr run --cmd "orca images" /dev/null
  ```

- Inline
  ```sh
  az acr run \
    --cmd "orca run demo42t.azurecr.io/base-artifacts/azure-cli:2.0.75 echo beam me up" /dev/null
  ```

- Combined w/task-yaml

  ```sh
  cat acr-task.yaml
  az acr run -f acr-task.yaml /dev/null
  ```
