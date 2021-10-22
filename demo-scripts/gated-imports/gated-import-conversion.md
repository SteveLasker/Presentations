# Gated Import Workflows

This demo takes an takes the [gated import workflow](https://aka.ms/acr/tasks/gated-import) and establishes a reset to show:

## Demo Reset

Delete ACRs

```azurecli
az acr delete -n $REGISTRY -y
az acr delete -n $REGISTRY_BASE_ARTIFACTS -y
```


Change hello-world to build from public

```azurecli
az acr task update \
  -n hello-world \
  -r $REGISTRY \
  --set REGISTRY_FROM_URL=${REGISTRY_PUBLIC_URL}/ \
  --set KEYVAULT=$AKV \
  --set ACI=$ACI \
  --set ACI_RG=$ACI_RG
```

Delete `base-import-node`

```azurecli
az acr task delete \
  --name base-import-node \
  -r $REGISTRY_BASE_ARTIFACTS \
  -y
```

Delete REGISTRY_BASE_ARTIFACTS

```azurecli
az acr delete -n $REGISTRY_BASE_ARTIFACTS -y
```
### Create task to import and test base image




### Create REGISTRY_BASE_ARTIFACTS

m```azurecli
az acr create \
  --resource-group $REGISTRY_BASE_ARTIFACTS_RG \
  --name $REGISTRY_BASE_ARTIFACTS \
  --sku Premium
```




Change `base-import-node` to not trigger

```azurecli
az acr task update \
  --name base-import-node \
  -r $REGISTRY_BASE_ARTIFACTS \
  -f acr-task.yaml \
  --set REGISTRY_FROM_URL=${REGISTRY_PUBLIC_URL}/ \
  --context ${GIT_NODE_IMPORT}/foo
  ```

Change base-image-node to a baseline color

- Open $GIT_BASE_IMAGE_NODE
- Change `Dockerfile`
    ```dockerfile
    ARG REGISTRY_NAME=
    FROM ${REGISTRY_NAME}node:15-alpine
    ENV NODE_VERSION 15-alpine
    ENV BACKGROUND_COLOR blue
    ```

az acr task update \
  -n hello-world \
  -r $REGISTRY \
  --set REGISTRY_FROM_URL=${REGISTRY_BASE_ARTIFACTS_URL}/ \
  --set KEYVAULT=$AKV \
  --set ACI=$ACI \
  --set ACI_RG=$ACI_RG


## Step 1 - Prerequisites

- Public Registry
  - With node auto-built from git
  - With credentials for GitHub
- Team Registry
- ACI Resource Group


## Step 2 - Build & deploy hello-world

- Create keyvault entries for FROM registry user/password
  - Normally Docker Hub

