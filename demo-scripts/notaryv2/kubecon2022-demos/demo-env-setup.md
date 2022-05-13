# Notary v2 KubeCon 2022 EU Demo Script

> TODO
- Add an ACME Rockets Key Vault, signature and key
- Add promotion scenario for re-signing the net-monitor key
- Add an SBOM to the net-monitor image using the buildkit output
- Add a SNYK scan result

Questions
  Should I run a local instance of k8s, or is demoing AKS ok for simplicity of setup?

## Demo Elements

- Notary Sign/Validate with CNCF Distribution and/Zot
- Notary Sign with Remote Key Vault Providers (Azure Key Vault)
- Notation Verification, through policy configuration
- Notation Verification of Microsoft Distributed Content

## Acquisition

Get the components

### Install ORAS 

Install the ORAS [v0.2.1-alpha.1](https://github.com/oras-project/oras/releases/tag/v0.2.1-alpha.1) cli for pushing, discovering, pulling artifacts to a registry  

  ```bash
  curl -LO https://github.com/oras-project/oras/releases/download/v0.2.1-alpha.1/oras_0.2.1-alpha.1_linux_amd64.tar.gz

  mkdir oras

  tar -xvf ./oras_0.2.1-alpha.1_linux_amd64.tar.gz -C ./oras/

  cp ./oras/oras ~/bin
  ```

### Install `notation` with plugin support 

From [notation feat-kv-extensibility branch](https://github.com/notaryproject/notation/releases/tag/feat-kv-extensibility)

  ```bash
  # Choose a binary
  TIMESTAMP=20220121081115
  COMMIT=17c7607

  # Download, extract and install
  curl -Lo notation.tar.gz https://github.com/notaryproject/notation/releases/download/feat-kv-extensibility/notation-feat-kv-extensibility-$TIMESTAMP-$COMMIT.tar.gz

  tar xvzf notation.tar.gz

  tar xvzf notation_0.0.0-SNAPSHOT-${COMMIT}_linux_amd64.tar.gz -C ~/bin notation
  ```
### Install the Azure Key Vault Plug-in

- Download the Azure Key Vault Plug-in

  ```bash
  # Create a directory for the plugin
  mkdir -p ~/.config/notation/plugins/azure-kv

  # Download the plugin
  curl -Lo notation-azure-kv.tar.gz \
      https://github.com/Azure/notation-azure-kv/releases/download/v0.1.0-alpha.1/notation-azure-kv_0.1.0-alpha.1_Linux_amd64.tar.gz

  # Extract to the plugin directory    
  tar xvzf notation-azure-kv.tar.gz -C ~/.config/notation/plugins/azure-kv notation-azure-kv
  ```

- Configure the Azure Key Vault plugin for notation

  ```bash
  notation plugin add azure-kv ~/.config/notation/plugins/azure-kv/notation-azure-kv
  ```

- List the available plugins and verify that the plug in available

  ```bash
  notation plugin ls
  ```

- Install `kustomiz`  
  https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/

```bash
chmod +x ./kustomize
cp ./kustomize ~/bin
```

## Variables

The variables needed for each run of the demo

Change to your environment.

- ACR  

  ```bash
  export ACR_NAME=wabbitnetworks
  export REGISTRY=$ACR_NAME.azurecr.io
  export ACR_RG=${ACR_NAME}-acr-rg
  ```

- Net Monitor Repo/Image Reference

  ```bash
  export REPO=net-monitor
  export TAG=v1
  export IMAGE=$REGISTRY/${REPO}:$TAG
  export LOCATION=southcentralus
  ```

- Azure Key Vaults
  used to store the signing keys

  ```bash
  # ISV Keys for signing public software
  export ISV_AKV_NAME=wabbitnetworks
  # Key name used to sign and verify
  export ISV_KEY_NAME=wabbit-networks-io
  export ISV_KEY_SUBJECT=wabbit-networks.io
  export ISV_AKV_RG=${ISV_AKV_NAME}-akv-rg

  # Consumer Keys for attesting to imported public software
  export ACME_AKV_NAME=acmerockets
  # Key name used to sign and verify
  export ACME_KEY_NAME=acmerockets-approved
  export ACME_KEY_SUBJECT=acmerockets-approved
  export ACME_AKV_RG=${ACME_AKV_NAME}-akv-rg
  ```

- Azure Kubernetes Service
  ```bash
  AKS_NAME=acme-rockets-dev
  AKS_RG=${AKS_NAME}-aks-rg
  ```

## Create Resources

If the resources already exist, skip to [Demo Setup](#demo-setup)

Build out the infra required for the demo
- Create an ACR Instance
  ```bash
  az group create \
    --name $ACR_NAME \
    --location $LOCATION

  az acr create \
    --resource-group $ACR_RG \
    --name $ACR_NAME \
    --zone-redundancy enabled \
    --sku Premium \
    --output jsonc
  ```

- Create Azure Key Vaults for secure key storage and remote signing.

  ```azurecli
  # ISV Key Vault
  az group create \
    --name $ISV_AKV_RG \
    --location $LOCATION

  az keyvault create \
    --name $ISV_AKV_NAME \
    --resource-group $ISV_AKV_RG \
    --location $LOCATION

  # ACME Key Vault
  az group create \
    --name $ACME_AKV_RG \
    --location $LOCATION

  az keyvault create \
    --name $ACME_AKV_NAME \
    --resource-group $ACME_AKV_RG \
    --location $LOCATION
  ```

### Store signing certificates in Azure Key Vaults

Create or provide an x509 signing certificate, storing it in Azure Key Vault for remote signing.

- Create an ISV certificate policy file

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
        "subject": "CN=${ISV_KEY_SUBJECT}",
        "validityInMonths": 12
        }
    }
    EOF
    ```

- Create the ISV certificate

    ```azure-cli
    az keyvault certificate create \
      -n $ISV_KEY_NAME \
      --vault-name $ISV_AKV_NAME \
      -p @my_policy.json
    ```

- Create an ACME certificate policy file

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
        "subject": "CN=${ACME_KEY_SUBJECT}",
        "validityInMonths": 12
        }
    }
    EOF
    ```

- Create the ACME certificate

    ```azure-cli
    az keyvault certificate create \
      -n $ACME_KEY_NAME \
      --vault-name $ACME_AKV_NAME \
      -p @my_policy.json
    ```

### Create an Azure Kubernetes Cluster  

If needed, create an Azure Kubernetes Cluster

- Create an Azure resource group:

    ```azurecli-interactive
    az group create -n $AKS_RG -l $LOCATION
    ```

- Create an AKS cluster with the [az aks create][az-aks-create] command.

    ```azurecli-interactive
    az aks create -n $AKS_NAME -g $AKS_RG
    az aks update -n $AKS_NAME -g $AKS_RG --attach-acr $ACR_NAME
    ```

- Get the AKS credentials

    ```azurecli-interactive
    az aks get-credentials -n $AKS_NAME -g $AKS_RG
    ```
### Configure permissions for ratify

- Create an ACR Token for Ratify to access the registry

    ```azure-cli
    export RATIFY_USERNAME=$ACR_NAME'-token'
    export RATIFY_PASSWORD=$(az acr token create -n $RATIFY_USERNAME \
                        -r $ACR_NAME \
                        --scope-map _repositories_admin \
                        --only-show-errors \
                        -o json | jq -r ".credentials.passwords[0].value")
    ```

- Configure registry creds to pull images within Ratify

    ```bash
    kubectl create secret docker-registry regcred \
        --docker-server=$REGISTRY \
        --docker-username=$RATIFY_USERNAME \
        --docker-password=$RATIFY_PASSWORD \
        --docker-email=someone@example.com
    ```

- Add Gatekeeper

  ```bash
  helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts

  helm update --install gatekeeper/gatekeeper  \
      --name-template=gatekeeper \
      --namespace gatekeeper-system --create-namespace \
      --set enableExternalData=true \
      --set validatingWebhookTimeoutSeconds=7
  ```

- Add Ratify for validations

  ```bash
  helm repo add ratify https://deislabs.github.io/ratify
  ```

- Configure Ratify with a public key

  ```bash
  kubectl create ns demo

  export PUBLIC_KEY=$(az keyvault certificate show -n $ISV_KEY_NAME \
                        --vault-name $ISV_AKV_NAME \
                        -o json | jq -r '.cer' | base64 -d | openssl x509 -inform DER)

  helm upgrade --install ratify ratify/ratify --atomic \
      --set registryCredsSecret=regcred \
      --set ratifyTestCert="$PUBLIC_KEY"

  kubectl apply -f ./constraint.yaml

  #kubectl run demo --image=$IMAGE -n demo
  #kubectl run demo --image=wabbitnetworks.azurecr.io/net-monitor:v2 -n demo
  #kubectl get pods -n demo
  #kubectl delete pod demo -n demo
  ```

