Notary v2 - Remote Signing and Verification with Gatekeeper, Ratify and AKS

## Preset

### Install the notation cli and akv plugin

> NOTE: These are temporary steps for early development. Officially released binaries will be available as the project stabilizes.

1. Build a version of notation that supports extensibility

    ```bash
    git clone git@github.com:aramase/notation.git -b plugin
    cd notation
    make build
    # Copy the notation cli to your bin directory
    cp ./bin/notation ~/bin
    ```

1. Build the notation-akv plugin for remote signing and verification

    ```bash
    # Move back to the root directory
    cd ../
    git clone git@github.com:Azure/notation-akv.git -b dev
    cd notation-akv
    make build
    ```

2. Copy the plugin to the notation plugin directory

    ```bash
    mkdir -p ~/.config/notation/plugins/azure-kv
    cp ./bin/notation-akv ~/.config/notation/plugins/azure-kv
    ```

### Configure Environment Variables

To ease the execution of the commands to complete this article, provide values for the Azure resources.

1. Configure Azure Resource Names and Locations

    > TODO: Remove wabbitnetworks names

    ```bash
    # location resources will be created in. During Preview of ORAS Artifact support, SouthCentralUS is the only supported region.
    LOCATION=southcentralus

    # Name of the registry example: myregistry.azurecr.io
    ACR_NAME=wabbitnetworks #myregistry
    # Name of the ACR Resource Group
    ACR_RG=${ACR_NAME}-acr-rg
    # Full domain of the ACR
    REGISTRY=$ACR_NAME.azurecr.io
    
    # Name of the Azure Key Vault used to store the signing keys
    AKV_NAME=wabbitnetworks #myakv
    # Key name used to sign and verify
    KEY_NAME=wabbit-networks-io
    KEY_SUBJECT_NAME=wabbit-networks.io
    # Name of the AKV Resource Group
    AKV_RG=${AKV_NAME}-akv-rg

    # Name of the Azure Kubernetes Service instance
    AKS_NAME=wabbitnetworks #myaks
    AKS_RG=${AKS_NAME}--aks-rg
    ```

2. Configure container image resources
    ```bash
    ACR_REPO=net-monitor
    IMAGE_SOURCE=https://github.com/wabbit-networks/net-monitor.git#main
    IMAGE_TAG=v1
    IMAGE=$REGISTRY/${ACR_REPO}:$IMAGE_TAG
    ```

### Configure Azure Key Vault

1. If you don't already have a Key Vault, configure an Azure Key Vault for secure key storage and remote signing.

    ```azurecli
    az group create --name $AKV_RG --location $LOCATION
    az keyvault create --name $AKV_NAME --resource-group $AKV_RG --location $LOCATION
    ```

2. Create a service principal

    ```bash
    # Service Principal Name
    SP_NAME=https://${AKV_NAME}-sp

    # Create the service principal, capturing the password
    SP_PASSWORD=$(az ad sp create-for-rbac --skip-assignment --name $SP_NAME --query "password" --output tsv)

    # Capture the service srincipal appId
    SP_APP_ID=$(az ad sp list --display-name $SP_NAME --query "[].appId" --output tsv)

    # Capture the Azure Tenant ID
    TENANT_ID=$(az account show --query "tenantId" -o tsv)
    ```

3. Assign key and certificate permissions to the service principal object id

    ```azure-cli
    az keyvault set-policy --name $AKV_NAME --key-permissions get sign --spn $SP_APP_ID

    az keyvault set-policy --name $AKV_NAME --certificate-permissions get --spn $SP_APP_ID
    ```

4. Create a credentials file for notation-akv plugin

    ```bash
    mkdir -p ~/.config/notation-akv/
    cat <<EOF > ~/.config/notation-akv/config.json
    {
      "credentials": {
        "clientId": "$SP_APP_ID",
        "clientSecret": "$SP_PASSWORD",
        "tenantId": "$TENANT_ID"
      }
    }
    EOF
    ```

### Configure the notation Azure Key Vault plugin

1. Add the Plugin

    ```bash
    notation plugin add azure-kv ~/.config/notation/plugins/azure-kv/notation-akv
    ```

2. List the available plugins

    ```bash
    notation plugin ls
    ```

### Configure an Azure container registry

1. Create an Azure container registry, capable of storing signed container images.
    ```azurecli
    az group create --name $ACR_NAME --location $LOCATION

    az acr create \
      --resource-group $ACR_NAME \
      --name $ACR_NAME \
      --zone-redundancy enabled \
      --sku Premium \
      --output jsonc
    ```
    In the command output, note the `zoneRedundancy` property for the registry. When enabled, the registry is zone redundant, and ORAS Artifact enabled:

    ```JSON
    {
      [...]
      "zoneRedundancy": "Enabled",
    }
    ```

### Create an Azure Kubernetes Cluster

If needed, create an Azure Kubernetes Cluster

1. Create an Azure resource group:

    ```azurecli-interactive
    az group create -n $AKS_RG -l $LOCATION
    ```

2. Create an AKS cluster with the [az aks create][az-aks-create] command.

    ```azurecli-interactive
    az aks create -n $AKS_NAME -g $AKS_RG #--attach-acr $ACR_NAME
    az aks update -n $AKS_NAME -g $AKS_RG --attach-acr $ACR_NAME
    ```

3. Get the AKS credentials

    ```azurecli-interactive
    az aks get-credentials -n $AKS_NAME -g $AKS_RG
    ```

3. Create an ACR Token for notation signing and the ORAS cli to access the registry

    ```azure-cli
    export NOTATION_USERNAME=$ACR_NAME'-token'
    export NOTATION_PASSWORD=$(az acr token create -n $NOTATION_USERNAME \
                        -r $ACR_NAME \
                        --scope-map _repositories_admin \
                        --only-show-errors \
                        -o json | jq -r ".credentials.passwords[0].value")
    ```

4. Configure permissions for ratify
    > NOTE: these are temporary steps. Ratify should use the node secrets, using ACR
    ```bash
    kubectl create secret docker-registry regcred \
        --docker-server=$REGISTRY \
        --docker-username=$NOTATION_USERNAME \
        --docker-password=$NOTATION_PASSWORD \
        --docker-email=someone@example.com
    ```

### Install Gatekeeper

In this step, Gatekeeper will be configured, enabling deployment policies.

1. install Gatekeeper

    ```azurecli-interactive
    helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts

    helm install gatekeeper/gatekeeper  \
        --name-template=gatekeeper \
        --namespace gatekeeper-system --create-namespace \
        --set enableExternalData=true \
        --set controllerManager.dnsPolicy=ClusterFirst,audit.dnsPolicy=ClusterFirst
    ````
 
 ## Demo Steps

We're starting with the following basic Azure service configurations

- An ACR with ORAS Artifacts Support, enabling graphs of supply chain artifacts
- An AKS instance, linked to ACR for pulling images
- AKS with Gatekeeper support

We'll now demo:

1. Creating a cert in Azure Key Vault, used for remote signing
   1. The cert can be a CA issues, or self-signed cert. It's really up to the the user whether they need revocation for their controlled environment scenarios
2. Secure a namespace with images with trusted signatures
3. Build an image
4. Remotely sign the image with Azure Key Vault
5. Deploy the image to AKS - with a success
6. Attempt to deploy an unsigned image, and watch it fail.

### Deploy an image

1. Create a namespace in AKS

    ```azurecli-interactive
    kubectl create ns freezone
    ```

2. Deploy `hello-world:latest` to show a functioning cluster

    ```bash
    kubectl run hello-world --image=mcr.microsoft.com/azuredocs/aci-helloworld:latest -n freezone
    ```

3. List the running pods

    ```bash
    kubectl get pods -A
    ```

## Store the signing certificate in Azure Key Vault

Create or provide an x509 signing certificate, storing it in Azure Key Vault for remote signing.

1. Create a certificate policy file

    ```bash
    cat <<EOF > ./my_policy.json
    {
        "issuerParameters": {
        "certificateTransparency": null,
        "name": "Self"
        },
        "x509CertificateProperties": {
        "ekus": [
            "1.3.6.1.5.5.7.3.1",
            "1.3.6.1.5.5.7.3.2",
            "1.3.6.1.5.5.7.3.3"
        ],
        "subject": "CN=${KEY_SUBJECT_NAME}",
        "validityInMonths": 12
        }
    }
    EOF
    ```

2. Create the certificate
    ```azure-cli
    az keyvault certificate create -n $KEY_NAME --vault-name $AKV_NAME -p @my_policy.json
    ```

3. Get the Key Id for the certificate

    ```bash
    KEY_ID=$(az keyvault certificate show --vault-name $AKV_NAME \
                        --name $KEY_NAME \
                        --query "kid" -o tsv)
    ```

4. Add the Key Id to the kms keys and certs

    ```bash
    notation key add --name $KEY_NAME --plugin azure-kv --id $KEY_ID --kms
    notation cert add --name $KEY_NAME --plugin azure-kv --id $KEY_ID --kms
    ```

5. List the keys and certs to confirm

    ```bash
    notation key ls
    notation cert ls
    ```

## Secure AKS with Ratify

1. Capture the public key for verification

    ```azure-cli
    az keyvault certificate download \
      -n $KEY_NAME \
      --vault-name $AKV_NAME \
      -f file.pem
    
    export PUBLIC_KEY=$(cat file.pem)
    ```

1. Create a namespace in AKS

    ```azurecli-interactive
    kubectl create ns demo
    ```

2. Install Ratify

    ```azurecli-interactive
    # Temporary, until the ratify chart is published
    git clone https://github.com/deislabs/ratify.git


    helm install ratify ratify/charts/ratify \
        --set registryCredsSecret=regcred \
        --set ratifyTestCert=$PUBLIC_KEY

    kubectl apply -f ./ratify/charts/ratify-gatekeeper/templates/constraint.yaml

    cat ./ratify/charts/ratify-gatekeeper/templates/constraint.yaml
    ```

2. Deploy `hello-world:latest` to show a functioning cluster

    ```bash
    kubectl run hello-world \
      --image=mcr.microsoft.com/azuredocs/aci-helloworld:latest \
      -n demo
    ```

3. List the running pods

    ```bash
    kubectl get pods -A
    ```

## Build an Image

1. Build and Push a new image with ACR Tasks

    ```azure-cli
    az acr build -r $ACR_NAME -t $IMAGE $IMAGE_SOURCE
    ```

2. Sign the container image

    ```bash
    notation sign --key $KEY_NAME $IMAGE 
    ```

3. Deploy the signed `net-monitor:v1` image

    ```bash
    kubectl run net-monitor --image=$IMAGE -n demo
    ```

3. List the running pods

    ```bash
    kubectl get pods -A
    ```

4. Delete the pod

    ```bash
    kubectl delete pod net-monitor -n demo
    ```

## Demo Reset

- Remove keys, certificates and notation `config.json`
  ```bash
  rm ./file.pem
  rm ~/.config/notation/config.json
  #rm ~/.config/notation-akv/config.json
  ```

1. Add the Plugin

    ```bash
    notation plugin add azure-kv ~/.config/notation/plugins/azure-kv/notation-akv
    ```

    ```bash
    az keyvault certificate delete -n $KEY_NAME --vault-name $AKV_NAME
    az keyvault certificate purge --vault-name $AKV_NAME --name $KEY_NAME
    ```

- Clear the ACR repo
  ```bash
  az acr repository delete \
    -n $ACR_NAME \
    --repository $ACR_REPO -y
  ```

- Clear up AKS resources

  ```bash
  helm uninstall ratify
  kubectl delete ns demo
  kubectl delete ns freezone
  ```

## Cleanup Resources

```azurecli
az aks delete --yes -n $AKS_NAME -g $AKS_RG
```