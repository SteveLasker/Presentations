# Teleport Baseline Demos

A scratchpad of demos for now...

## Your Environment Names

```sh
export ACR_NAME=[yourRegistryName] #eg: demo42
export LOCATION=soutchcentralus
export RESOURCE_GROUP=$ACR_NAME
```

## Setting up the Environment

- Create a ACR. For preview, teleportation requires a premium registry.

```sh
az acr create -n $ACR_NAME -l $LOCATION -g $RESOURCE_GROUP --sku premium
```

- Enable for Teleportation
  Request Access at https://aka.ms/teleport/signup

- Import Images

```sh
#az acr import \
#  -n ${ACR_NAME} \
#  --source mcr.microsoft.com/dotnet/core/runtime:2.1.10 \
#  --image base-images/dotnet/core/runtime:2.1.10

docker pull mcr.microsoft.com/dotnet/core/runtime:2.1.10
docker tag mcr.microsoft.com/dotnet/core/runtime:2.1.10 ${ACR_NAME}.azurecr.io/base-images/dotnet/core/runtime:2.1.10

docker push ${ACR_NAME}.azurecr.io/base-images/dotnet/core/runtime:2.1.10
docker pull ${ACR_NAME}.azurecr.io/base-images/dotnet/core/runtime:2.1.10


#az acr import \
#  -n ${ACR_NAME} \
#  --source mcr.microsoft.com/dotnet/core/sdk:2.1 \
#  --image base-images/dotnet/core/sdk:2.1

docker pull mcr.microsoft.com/dotnet/core/sdk:2.1
docker tag mcr.microsoft.com/dotnet/core/sdk:2.1 ${ACR_NAME}.azurecr.io/base-images/dotnet/core/sdk:2.1
docker push ${ACR_NAME}.azurecr.io/base-images/dotnet/core/sdk:2.1

docker pull ${ACR_NAME}.azurecr.io/base-images/dotnet/core/sdk:2.1

#az acr import \
#  -n ${ACR_NAME} \
#  --source mcr.microsoft.com/dotnet/core/sdk:2.2 \
#  --image base-images/dotnet/core/sdk:2.2

docker pull mcr.microsoft.com/dotnet/core/sdk:2.2
docker tag mcr.microsoft.com/dotnet/core/sdk:2.2 ${ACR_NAME}.azurecr.io/dotnet/core/sdk:2.2
docker push ${ACR_NAME}.azurecr.io/base-images/dotnet/core/sdk:2.2
docker pull ${ACR_NAME}.azurecr.io/base-imagesdotnet/core/sdk:2.2

#az acr import \
#  -n ${ACR_NAME} \
#  --source mcr.microsoft.com/azure-cli:2.0.75 \
#  --image azure-cli:2.0.75
docker pull mcr.microsoft.com/azure-cli:2.0.75
docker tag mcr.microsoft.com/azure-cli:2.0.75 ${ACR_NAME}.azurecr.io/azure-cli:2.0.75
docker push ${ACR_NAME}.azurecr.io/azure-cli:2.0.75

docker pull mcr.microsoft.com/azure-cli:latest
docker tag mcr.microsoft.com/azure-cli:latest ${ACR_NAME}.azurecr.io/azure-cli:latest
docker push ${ACR_NAME}.azurecr.io/azure-cli:latest

#az acr import \
#  -n ${ACR_NAME} \
#  --source demo42.azurecr.io/demo42/queueworker:1 \
#  --image demo42/queueworker:1

#az acr import \
#  -n ${ACR_NAME} \
#  --source demo42.azurecr.io/demo42/web:1 \
#  --image demo42/web:1
```

## Create A Comparison VM

- Install a VM from this template

  https://github.com/Azure/azure-quickstart-templates/tree/master/docker-simple-on-ubuntu

- Install the AZ CLI

  ```sh
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  ```

- Login and Configure the AZ CLI

```sh
az login
az configure
```

## Pre Demo

The following is needed to start the demo:

- SSH into the Docker VM

  ```sh
  ssh stevelas@stevelasteleportvm.southcentralus.cloudapp.azure.com
  ```

- ACR Login

  ```sh
  az login
  az acr login -n $ACR_NAME
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

## Demo Time

## VM Comparison

- Baseline Azure CLI

```sh
# 182 MB - 6 layers
time docker run --rm demo42t.azurecr.io/demo42/queueworker:no-entrypoint echo hello
# 931 MB - 11 layers
time docker run --rm demo42t.azurecr.io/azure-cli:2.0.75 echo 'hello'
# 5 GB - 34 layers 373.38 seconds
time docker run --rm demo42t.azurecr.io/spark-notebook:1 echo hello
# 1.8k - 1 layer 1.8 seconds
time docker run --rm demo42t.azurecr.io/hello-world:latest
```

## ACI Baseline

```sh
time az container create \
  --resource-group aci \
  --name demo42-queueworker \
  --image ${ACR_NAME}.azurecr.io/demo42/queueworker:no-entrypoint \
  --command-line "echo hello" \
  --registry-login-server ${ACR_NAME}.azurecr.io \
  --registry-username $ACR_USER \
  --registry-password $ACR_PWD \
  --restart-policy Never

az container delete --resource-group aci --name demo42-queueworker -y
```

```sh
time az container create \
  --resource-group aci \
  --name az-cli \
  --image ${ACR_NAME}.azurecr.io/azure-cli:2.0.75  \
  --registry-login-server ${ACR_NAME}.azurecr.io \
  --registry-username $ACR_NAME \
  --registry-password $ACR_PWD \
  --restart-policy Never

az container delete --resource-group aci --name az-cli -y
```

```sh
time az container create \
  --resource-group aci \
  --name spark-notebook \
  --image demo42t.azurecr.io/spark-notebook:1 \
  --command-line "echo hello" \
  --registry-login-server ${ACR_NAME}.azurecr.io \
  --registry-username $ACR_USER \
  --registry-password $ACR_PWD \
  --restart-policy Never

az container delete --resource-group aci --name spark-notebook -y
```

```sh
time az container create \
  --resource-group aci \
  --name hello-world \
  --image demo42t.azurecr.io/hello-world:latest \
  --registry-login-server ${ACR_NAME}.azurecr.io \
  --registry-username $ACR_USER \
  --registry-password $ACR_PWD \
  --restart-policy Never

az container delete --resource-group aci --name hello-world -y
```

## ACR Tasks, w/Teleport

```sh
az acr run -r demo42t \
  --cmd "orca run demo42t.azurecr.io/demo42/queueworker:no-entrypoint echo hello" /dev/null

az acr run -r demo42t \
  --cmd "orca run demo42t.azurecr.io/azure-cli:2.0.75 echo hello" /dev/null

az acr run -r demo42t \
  --cmd "orca run demo42t.azurecr.io/spark-notebook:1 echo hello" /dev/null

az acr run -r demo42t \
  --cmd "orca run demo42t.azurecr.io/hello-world:latest" /dev/null
```

## Multi-step Task Samples

### Basic Task Sample

```sh
az acr run -r demo42t \
  -f pre-cache-task.yaml \
  /dev/null
```

# Extra Stuff

- ACR Login

  ```sh
  ACR_NAME=demo42t
  az login
  az acr login -n $ACR_NAME
  ACR_USER=${ACR_NAME}
  ACR_PWD="$(az acr credential show -n ${ACR_NAME} --query passwords[0].value -o tsv)"
  ```

## Clear any images

  ```sh
  docker rm -f $(docker ps -a -q)
  docker rmi $(docker images -a -q)
  docker ps -a
  docker images -a
  clear
  ```
## Demo Time

## VM Comparison

- Baseline Azure CLI

```sh
docker images

# 931 MB - 11 layers
time docker run --rm demo42t.azurecr.io/azure-cli:2.0.75 echo 'hello'
```

## ACI Comparison

```sh
time az container create \
  --resource-group aci \
  --name az-cli \
  --image ${ACR_NAME}.azurecr.io/azure-cli:2.0.75  \
  --registry-login-server ${ACR_NAME}.azurecr.io \
  --registry-username $ACR_NAME \
  --registry-password $ACR_PWD \
  --restart-policy Never

az container delete --resource-group aci --name az-cli -y
```

## ACR Tasks, w/Teleport

```sh
az acr run -r demo42t \
  --cmd "orca run demo42t.azurecr.io/azure-cli:2.0.75 echo hello" /dev/null
```
