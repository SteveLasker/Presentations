
```sh
ACR_NAME=demo42
LOCATION=southcentralus
```

```sh
az acr create -n ${ACR_NAME}baseartifacts -g ${ACR_NAME} -l ${LOCATION} --sku standard
az acr create -n ${ACR_NAME}dev -g ${ACR_NAME} -l ${LOCATION} --sku premium
az acr create -n ${ACR_NAME}prod -g ${ACR_NAME} -l ${LOCATION} --sku premium
az acr create -n ${ACR_NAME}archive -g ${ACR_NAME} -l ${LOCATION} --sku standard
az acr create -n ${ACR_NAME}upstream -g ${ACR_NAME} -l ${LOCATION} --sku standard
```
