## Demo Reset

Steps to run before a demo to reset the environment

- Remove the remote signing plugin
  ```bash
  kubectl delete pod --all -n not-secured
  kubectl delete pod --all -n secured
  kubectl delete ns secured
  kubectl delete ns not-secured
  az acr repository delete -n wabbitnetworks --repository net-monitor -y
  az acr repository delete -n acmerockets --repository library/net-monitor -y
  az acr repository delete -n wabbitnetworks --repository library/nginx -y
  notation cert remove wabbit-networks-test
  notation key remove wabbit-networks-test
  notation cert remove wabbit-networks-io
  notation key remove wabbit-networks-io
  rm ~/.config/notation/key/wabbit-networks-test.key
  rm ~/.config/notation/certificate/wabbit-networks-test.crt
  ```

## Demo Setup

Steps if the environment is setup, but not run in a current session

- Update the ACR credentials
  ```bash
  az acr login -n wabbitnetworks.azurecr.io
  az acr login -n acmerockets.azurecr.io
  ```

- Create a Service Principal for Resource Access (see [issue #20](https://github.com/Azure/notation-azure-kv/issues/20) for more simplicity)

    ```bash
    # Service Principal Name
    SP_NAME=https://${ISV_AKV_NAME}-sp

    # Create the service principal, capturing the password
    export AZURE_CLIENT_SECRET=$(az ad sp create-for-rbac --skip-assignment --name $SP_NAME --query "password" --output tsv)

    # Capture the service srincipal appId
    export AZURE_CLIENT_ID=$(az ad sp list --display-name $SP_NAME --query "[].appId" --output tsv)
    
    # Capture the Azure Tenant ID
    export AZURE_TENANT_ID=$(az account show --query "tenantId" -o tsv)
    ```

- Assign key and certificate permissions to the service principal object ids

    ```bash
    # ISV Key Vault
    az keyvault set-policy --name $ISV_AKV_NAME --key-permissions get sign --spn $AZURE_CLIENT_ID

    az keyvault set-policy --name $ISV_AKV_NAME --certificate-permissions get --spn $AZURE_CLIENT_ID

    # ACME  Key Vault
    az keyvault set-policy --name $ACME_AKV_NAME --key-permissions get sign --spn $AZURE_CLIENT_ID

    az keyvault set-policy --name $ACME_AKV_NAME --certificate-permissions get --spn $AZURE_CLIENT_ID
    ```

- Get the Key Id for the certificate

    ```bash
    KEY_ID=$(az keyvault certificate show --vault-name $ISV_AKV_NAME \
                        --name $ISV_KEY_NAME \
                        --query "kid" -o tsv)
    ```

- Add notation username/password, using your current AAD token

  ```bash
  export NOTATION_USERNAME="00000000-0000-0000-0000-000000000000"
  export NOTATION_PASSWORD=$(az acr login --name $ACR_NAME --expose-token --output tsv --query accessToken)
  ```
