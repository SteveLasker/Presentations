# ACR Tag Locking

Documentation: [Lock a container image in an Azure container registry](https://docs.microsoft.com/azure/container-registry/container-registry-image-lock)


## Demo Rest
az acr repository update \
    --name demo42 --image hello-world:latest \
    --delete-enabled true --write-enabled true \
    -o jsonc

## Demo Script
az acr repository show -t hello-world:latest -o jsonc

az acr repository update \
    --name demo42 --image hello-world:latest \
    --delete-enabled false --write-enabled false \
    -o jsonc

sudo docker pull hello-world

sudo docker tag hello-world demo42.azurecr.io/hello-world:latest

sudo docker push demo42.azurecr.io/hello-world:latest

az acr repository show -t hello-world:latest -o jsonc