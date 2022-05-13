# Claims Demo Script

## Preset

- Customize environment variables 

    ```bash
    # export ACR_NAME=stevelassc
    export ACR_NAME=wabbitnetworks
    export REGISTRY=$ACR_NAME.azurecr.io
    export ACR_RG=${ACR_NAME}-acr-rg
    export REPO=net-monitor
    export TAG=v1
    export IMAGE=$REGISTRY/${REPO}:$TAG
    export REGION=southcentralus
    export LOCATION=southcentralus

    # Name of the Azure Key Vault used to store the signing keys
    AKV_NAME=wabbitnetworks
    # Key name used to sign and verify
    KEY_NAME=wabbit-networks-io
    KEY_SUBJECT_NAME=wabbit-networks.io
    # Name of the AKV Resource Group
    AKV_RG=${AKV_NAME}-akv-rg
    ```
- Credentials for Azure Key Vault Plug-in  
  **Note:** these should be simplified, *quite a bit*
  ```bash
  # Service Principal Name
  SP_NAME=https://${AKV_NAME}-sp

  # Create the service principal, capturing the password
  export AZURE_CLIENT_SECRET=$(az ad sp create-for-rbac --skip-assignment --name $SP_NAME --query "password" --output tsv)

  # Create the service principal, capturing the password
  export AZURE_CLIENT_SECRET=$(az ad sp create-for-rbac --skip-assignment --name $SP_NAME --query "password" --output tsv)

  # Capture the service srincipal appId
  export AZURE_CLIENT_ID=$(az ad sp list --display-name $SP_NAME --query "[].appId" --output tsv)

  # Capture the Azure Tenant ID
  export AZURE_TENANT_ID=$(az account show --query "tenantId" -o tsv)
  ```

- Create an ACR Token for notation signing and the ORAS cli to access the registry

    ```bash
    export NOTATION_USERNAME=$ACR_NAME'-token'
    export NOTATION_PASSWORD=$(az acr token create -n $NOTATION_USERNAME \
                        -r $ACR_NAME \
                        --scope-map _repositories_admin \
                        --only-show-errors \
                        -o json | jq -r ".credentials.passwords[0].value")
    ```

## Demo Script

### Push a container image

This example associates a graph of artifacts to a container image. Build and push a container image, or reference an existing image in the private registry.

```bash
docker build -t $IMAGE https://github.com/wabbit-networks/net-monitor.git#main
docker push $IMAGE
```

- Sign the container image with Notary v2

  ```bash
  notation sign --key $KEY_NAME $IMAGE 
  ```

- Discover the graph

    ```console
    oras discover -o tree $IMAGE
    ```

- View in the [portal (preview)](https://aka.ms/acr/portal/preview)

### Step back and understand how the registry stored the signature

- Create some documentation around a specific artifact

  ```bash
  echo 'Readme Content' > readme.md
  echo 'Detailed Content' > readme-details.md
  ```

- Push the multi-file artifact as a reference

    ```bash
    oras push $REGISTRY/$REPO \
        --artifact-type 'readme/example' \
        --subject $IMAGE \
        ./readme.md:application/x.regdoc.overview.v0 \
        ./readme-details.md:application/x.regdoc.details.v0
    ```

### Push a claim  to the registry, as a reference to the container image

1. Create the claim

    ```bash
    DATETIME=$(date +%Y-%m-%dT%H:%M:%S)

    cat <<EOF > ./claims.json
    {
      "mediaType": "application/vnd.ietf.scitt.claim.v0.1",
      "claim-created": "$DATETIME",
      "claim-identity": "<identifier>",
      "subject": [
        {
          "io.cncf.oras.artifact.artifact-name": "io.wabbit-networks.registry/net-monitor:v1",
          "mediaType": "application/vnd.oci.image.manifest.v1+json",
          "digest": "sha256:41d62a3...110aa58a",
          "size": 25851449
        }
      ],
      "gov.nist.csrc.ssdf.1.1": "true",
      "io.something.else.important": "possible",
      "exclusions": [
        {
          "package": "name"
        }
      ]
    }
    EOF
    ```
- View the claim
  ```bash
  cat ./claims.json| jq
  ```

- Push the claim

    ```console
    oras push $REGISTRY/$REPO \
        --artifact-type 'application/vnd.ietf.scitt.claim.v1' \
        --subject $IMAGE \
        --manifest-annotations annotations.json \
        ./claims.json:application/json
    ```
- Discover the graph

    ```console
    oras discover -o tree $IMAGE
    ```

- Sign the claim
    ```bash
    CLAIMS_DIGEST=$(oras discover -o json \
                        --artifact-type application/vnd.ietf.scitt.claim.v1 \
                        $IMAGE | jq -r ".references[0].digest")
    
    echo $REGISTRY/$REPO@$CLAIMS_DIGEST
    
    notation sign --key $KEY_NAME \
      $REGISTRY/$REPO@$CLAIMS_DIGEST

    oras discover -o tree $IMAGE

    ```

- Discover a filtered graph

    ```bash
    oras discover -o tree \
      --artifact-type application/vnd.ietf.scitt.claim.v1 \
      $IMAGE
    ```


- Preview the claims manifest
  
    ```console
    CLAIMS_DIGEST=$(oras discover -o json \
                      --artifact-type application/vnd.ietf.scitt.claim.v1 \
                      $IMAGE | jq -r ".references[0].digest")

    az acr manifest show -r $ACR_NAME -n net-monitor@$CLAIMS_DIGEST -o jsonc
    ```

- Download the claims

    ```bash
    oras pull -a -o ./download $REGISTRY/$REPO@$CLAIMS_DIGEST
    ```
- View the claims
    ```bash
    cat ./download/claims.json | jq
    ```

## View the repository and tag listing

ORAS Artifacts enables artifact graphs to be pushed, discovered, pulled and copied without having to assign tags. This enables a tag listing to focus on the artifacts users think about, as opposed to the signatures and SBoMs that are associated with the container images, helm charts and other artifacts.

### View a list of tags

```azurecli
az acr repository show-tags \
  -n $ACR_NAME \
  --repository $REPO \
  -o jsonc
```

### View a list of manifests

A repository can have a list of manifests that are both tagged and untagged

```azurecli
az acr repository show-manifests \
  -n $ACR_NAME \
  --repository $REPO \
  --detail -o jsonc
```

Note the container image manifests have `"tags":`

```json
{
  "architecture": "amd64",
  "changeableAttributes": {
    "deleteEnabled": true,
    "listEnabled": true,
    "readEnabled": true,
    "writeEnabled": true
  },
  "configMediaType": "application/vnd.docker.container.image.v1+json",
  "createdTime": "2021-11-12T00:18:54.5123449Z",
  "digest": "sha256:a0fc570a245b09ed752c42d600ee3bb5b4f77bbd70d8898780b7ab4...",
  "imageSize": 2814446,
  "lastUpdateTime": "2021-11-12T00:18:54.5123449Z",
  "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
  "os": "linux",
  "tags": [
    "v1"
  ]
}
```

The signature is untagged, but tracked as a `oras.artifact.manifest` reference to the container image

```json
{
  "changeableAttributes": {
    "deleteEnabled": true,
    "listEnabled": true,
    "readEnabled": true,
    "writeEnabled": true
  },
  "createdTime": "2021-11-12T00:19:10.987156Z",
  "digest": "sha256:555ea91f39e7fb30c06f3b7aa483663f067f2950dcbcc0b0d...",
  "imageSize": 85,
  "lastUpdateTime": "2021-11-12T00:19:10.987156Z",
  "mediaType": "application/vnd.cncf.oras.artifact.manifest.v1+json"
}
```
## Delete all artifacts in the graph

Support for the ORAS Artifacts specification enables deleting the graph of artifacts associated with the root artifact. Use the [az acr repository delete][az-acr-repository-delete] command to delete the signature, SBoM and the signature of the SBoM.

```azurecli
az acr repository delete \
  -n $ACR_NAME \
  -t ${REPO}:$TAG -y
```

- View the remaining manifests

  ```azurecli
  az acr repository show-manifests \
    -n $ACR_NAME \
    --repository $REPO \
    --detail -o jsonc
  ```

- View in the [portal (preview)](https://aka.ms/acr/portal/preview)
- 

## Next steps

* Learn more about [the ORAS CLI](https://oras.land)
* Learn more about [ORAS Artifacts][oras-artifacts] for how to push, discover, pull, copy a graph of supply chain artifacts

<!-- LINKS - external -->
[docker-linux]:         https://docs.docker.com/engine/installation/#supported-platforms
[docker-mac]:           https://docs.docker.com/docker-for-mac/
[docker-windows]:       https://docs.docker.com/docker-for-windows/
[oras-install-docs]:    https://oras.land/cli/
[oras-preview-install]: https://github.com/oras-project/oras/releases/tag/v0.2.1-alpha.1
[oras-push-docs]:       https://oras.land/cli/1_pushing/
[oras-artifacts]:       https://github.com/oras-project/artifacts-spec/
<!-- LINKS - internal -->
[az-acr-repository-show]: /cli/azure/acr/repository?#az_acr_repository_show
[az-acr-repository-delete]: /cli/azure/acr/repository#az_acr_repository_delete