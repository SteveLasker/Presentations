## Demo Steps

### Image Signing

1. Run a local distribution or ZOT registry
1. Build a container image
1. Sign the container image
   1. Sign with a local key - but note this isn't a very secure model
   1. Show Azure KeyVault integration to demonstrate remote signing with a private key

### Deploy & Verify to k8S

1. Show deploying a signed image from wabbit networks - fail, as we don't trust anything but ACME Rocket signed images
1. Sign the image with our ACME Rockets key
2. Show deploying the image we just signed - pass
3. Explain the components used
   1. Gatekeeper
   2. Ratify
4. Add an SBOM
   1. Sign the SBOM
5. Add a security scan result (snyk)
   1. Sign the scan result
6. View the graph

### It's Real - Today

Show ZOT support
Show ACR Support
ACR Replication, to multiple regions

### Promotion

1. Promote to another registry
2. Sign the promoted content
3. Show the second signature

## Demo Local Signing

- Build the `net-monitor:v1` image

  ```bash
  docker build -t wabbitnetworks.azurecr.io/net-monitor:v1 \
    https://github.com/wabbit-networks/net-monitor.git#main

  docker push wabbitnetworks.azurecr.io/net-monitor:v1
  ```
- Create a local test cert
  ```bash
  notation cert generate-test --default "wabbit-networks-test"
  ````

- Sign the image

    ```bash
    notation sign --key "wabbit-networks-test" \
      wabbitnetworks.azurecr.io/net-monitor:v1 
    ```

- View the graph of content on net-monitor:v1

    ```bash
    oras discover -o tree wabbitnetworks.azurecr.io/net-monitor:v1 
    ```
- Verify the image
  ```bash
  notation verify wabbitnetworks.azurecr.io/net-monitor:v1
  ```
  **Note:** this fails as we have a no-trust default policy
  ```output
  FATA[0000] trust certificate not specified
  ```

- Add a trust certificate
  ```bash
  notation cert add --name "wabbit-networks-test" \
    ~/.config/notation/certificate/wabbit-networks-test.crt
  ```

- Verify the image, with our updated trust store

  ```bash
  notation verify wabbitnetworks.azurecr.io/net-monitor:v1
  ```

  Passes, as we now trust `wabbit-networks-test` certs
  ```output
  sha256:81a768032a0dcf5fd0d571092d37f2ab31afcac481aa91bb8ea891b0cff8a6ec  
  ```

- We can see the certificates we trust
  ```bash
  notation cert list
  ```
### Secure Remote Singing

Local certs are great for testing, but lets use a secured cert, in a remote key signing service

- Configure the Azure Key Vault plugin for notation

  ```bash
  notation plugin add \
      azure-kv ~/.config/notation/plugins/azure-kv/notation-azure-kv
  ```

- Get the KEY_ID for the remote signing service

    ```bash
    KEY_ID=$(az keyvault certificate show \
                            --vault-name wabbitnetworks \
                            --name wabbit-networks-io \
                            --query "kid" -o tsv)
    
    echo $KEY_ID
    ```

- Add the Key Id to the kms keys and certs  

    ```bash
    notation key add \
        --name wabbit-networks-io \
        --id $KEY_ID \
        --plugin azure-kv \
        --kms
    #notation cert add \
    #    --name wabbit-networks-io \
    #    --plugin azure-kv \
    #    --id $KEY_ID \
    #    --kms
    ```

- List the keys and certs to confirm

    ```bash
    notation key ls
    ```

- List the available plugins and verify that the plug in available

  ```bash
  notation plugin ls
  ```

- Sign the image

    ```bash
    notation sign --key "wabbit-networks-io" \
      wabbitnetworks.azurecr.io/net-monitor:v1 
    ```

- Sign the image

    ```bash
    oras discover -o tree \
      wabbitnetworks.azurecr.io/net-monitor:v1 
    ```

### Verification in k8s

Secure k8s with Gatekeeper, Ratify and Notary v2

- Create a secured and not-secured namespace

  ```bash
  kubectl create ns secured
  kubectl create ns not-secured
  ```

- Run nginx in the not-secured namespace
  ```bash
  kubectl run nginx \
    --image=nginx:1.21.6 \
    -n not-secured
  ```
- View the running pods
  ```bash
  kubectl get pods -n not-secured
  ```
### Secure A Namespace with Notary & Ratify

- Get the public key, we'll configure for validation

  ```bash
  export PUBLIC_KEY=$(az keyvault certificate show -n $ISV_KEY_NAME \
                        --vault-name $ISV_AKV_NAME \
                        -o json | jq -r '.cer' | base64 -d | openssl x509 -inform DER)
  ```
- Apply the key for verification

  ```bash
  helm upgrade --install ratify ratify/ratify --atomic \
      --set registryCredsSecret=regcred \
      --set ratifyTestCert="$PUBLIC_KEY"
  ```

- Apply the Ratify Constraint to a specific namespace

  ```bash
  cat <<EOF > ./constraint.yaml
  apiVersion: constraints.gatekeeper.sh/v1beta1
  kind: K8sSignedImages
  metadata:
    name: ratify-constraint
  spec:
    enforcementAction: deny
    match:
      kinds:
        - apiGroups: [""]
          kinds: ["Pod"]
      namespaces: ["secured"]
  EOF
  ```

- Apply the constrain
  ```bash
  kubectl apply -f ./constraint.yaml
  ```
- Run nginx in the secured namespace
  ```bash
  kubectl run nginx \
    --image=nginx:1.21.6 \
    -n secured
  ```

- Run our signed image in the secured namespace

  ```bash
  kubectl run net-monitor \
    --image=wabbitnetworks.azurecr.io/net-monitor:v1 \
    -n secured
  ```

- Import the nginx image, scan, sign and run

  ```bash
  docker pull nginx:1.21.6
  ```

- Scan the image for vulnerabilities

  ```bash
  docker scan nginx:1.21.6  
  ```

- Assuming your ok with the scan results, sign it for use within your environment
 
  ```bash
  docker tag nginx:1.21.6 \
      wabbitnetworks.azurecr.io/library/nginx:1.21.6
  
  docker push wabbitnetworks.azurecr.io/library/nginx:1.21.6

  notation sign --key "wabbit-networks-io" \
      wabbitnetworks.azurecr.io/library/nginx:1.21.6
  ```

- Run the scanned and signed image in the secured namespace

  ```bash
  kubectl run net-monitor \
    --image=wabbitnetworks.azurecr.io/library/nginx:1.21.6
    -n secured
  ```

- List the pods in each namespace
  ```bash
  kubectl get pods -n not-secured
  kubectl get pods -n secured
  ```

### Troubleshooting Commands

```bash
# Logs for a -p <named pod>, in a -n namespace
kubectl logs -p net-monitor -n secured
helm delete ratify
kubectl logs ratify-5dc476587b-j4glx
```
## APPENDIX

WIP to use the currently logged in user for setting the Azure Environment Variables

- Use the currently logged in user

  ```bash
  # Use the current signed in user
  export AZURE_CLIENT_ID=$(az ad signed-in-user show --query objectId --output tsv)

  export AZURE_CLIENT_SECRET=$(az ad sp create-for-rbac --skip-assignment --name $SP_NAME --query "password" --output tsv)

  # Capture the Azure Tenant ID
  export AZURE_TENANT_ID=$(az account show --query "tenantId" -o tsv)
  ```

- Assign key and certificate permissions to the service principal object id

    ```bash
    az keyvault set-policy --name $ISV_AKV_NAME --key-permissions get sign --object-id $AZURE_CLIENT_ID

    az keyvault set-policy --name $ISV_AKV_NAME --certificate-permissions get --object-id $AZURE_CLIENT_ID

  #kubectl apply -f ./mcr-nginx.yaml
    ```
