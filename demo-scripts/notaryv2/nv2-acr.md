# Notary v2 Quick Sign/Verify With ACR


## Preset
```bash
export ACR_NAME=wabbitnetworks
export REGISTRY=$ACR_NAME.azurecr-test.io
export REPO=${REGISTRY}/net-monitor
export IMAGE=${REPO}:v1

# Create an ACR
# Premium to use tokens
az acr create -n $ACR_NAME -g $(ACR_NAME)-acr --sku Premium
az configure --default acr=wabbitnetworks
az acr update --anonymous-pull-enabled true

# Using ACR Auth with Tokens
export NOTATION_USERNAME='wabbitnetworks-token'
export NOTATION_PASSWORD=$(az acr token create -n $NOTATION_USERNAME \
                    -r wabbitnetworks \
                    --scope-map _repositories_admin \
                    --only-show-errors \
                    -o json | jq -r ".credentials.passwords[0].value")
# notation
curl -Lo notation.tar.gz https://github.com/shizhMSFT/notation/releases/download/v0.7.0-shizh.2/notation_0.7.0-shizh.2_linux_amd64.tar.gz
tar xvzf notation.tar.gz -C ~/bin notation

# oras
curl -Lo oras.tar.gz https://github.com/shizhMSFT/oras/releases/download/v0.11.1-shizh.1/oras_0.11.1-shizh.1_linux_amd64.tar.gz
tar xvzf oras.tar.gz -C ~/bin oras

docker login $REGISTRY -u $NOTATION_USERNAME -p $NOTATION_PASSWORD
oras login $REGISTRY -u $NOTATION_USERNAME -p $NOTATION_PASSWORD

docker run -d -p ${PORT}:5000 ghcr.io/oras-project/registry:v0.0.3-alpha
```

## Demo

- View the [Azure Portal](https://df.onecloud.azure-test.net/?Microsoft_Azure_ContainerRegistries=true#@MSFT.ccsctp.net/resource/subscriptions/f9d7ebed-adbd-4cb4-b973-aaf82c136138/resourceGroups/wabbitnetworks-acr/providers/Microsoft.ContainerRegistry/registries/wabbitnetworks/repository)

- Build and push an image
```bash
  # Build and push to ACR
  docker build -t $IMAGE https://github.com/wabbit-networks/net-monitor.git#main
  docker push $IMAGE
```
- Generate a test certificate
    ```bash
    # Generate a test certificate
    notation cert generate-test --default "wabbit-networks.io"
    ```
- Sign the image
    ```bash
    notation sign $IMAGE
    ```
- List the signatures with notation
  ```bash
  # List the signatures
  notation list $IMAGE
  ```
- Verify the image, but no are yet keys are configured
  ```bash
  # Validation fails, as there are no public keys configured
  notation verify $IMAGE
  ```
- Configure a key for validation
  ```bash
  # Add the public key, used for validation
  notation cert add --name "wabbit-networks.io" \
    ~/.config/notation/certificate/wabbit-networks.io.crt
  ```
- View the configuration policy
  ```bash
  # View the configuration policy
  cat ~/.config/notation/config.json | jq
  ```
- Re-verify, with a configured key
  ```bash
  # Validation passes, as the signed key is part of the policy
  notation verify $IMAGE
  ```
- View the graph
  ```bash
  # View the graph of artifacts
  oras discover -o tree -u $NOTATION_USERNAME -p $NOTATION_PASSWORD $IMAGE
  ```
- View the tags
  ```bash
  # View the list of images we want to think about
  az acr repository show-tags -n wabbitnetworks --repository net-monitor -o jsonc
  ```  
- List the files
  ```bash
  # Just like we list files, we don't see the attributes
  ls -1
  ```
- List the files, w/attributes
  ```bash
  # Until we specifically ask for the attributes
  ls -lr
  ```
- View all manifests
  ```bash
  # View all the artifacts in the registry
  az acr repository show-manifests -n wabbitnetworks  --repository net-monitor -o jsonc
  ```
## Second Signature/Promotion
- List the images 
  ```bash
  docker images
  ```
- Clear the images as this is our production vm
  ```bash
  docker rmi -f $(docker images -q)
  ```
- Clear the configuration policy
  ```bash
  rm -r ~/.config/notation/
  ```
- Create a test cert for the ACME Rockets Library key
  ```bash
  notation cert generate-test \
    --default \
    "acme-rockets.io-library"
  ```
- View the configuration
  ```bash
  cat ~/.config/notation/config.json | jq
  ```
- Attempt to validate with the ACME Rockets key
  ```bash
  notation verify $IMAGE
  ```
- Sign the image with the Production cert
    ```bash
    notation sign $IMAGE
    ```
- Configure the ACME Rockets key for validation
  ```bash
  notation cert add --name "acme-rockets.io-library" \
    ~/.config/notation/certificate/acme-rockets.io-library.crt
  ```
- Validate with the ACME Rockets key
  ```bash
  notation verify $IMAGE
  ```
- View the graph
  ```bash
  # View the graph of artifacts
  oras discover -o tree \
    -u $NOTATION_USERNAME -p $NOTATION_PASSWORD $IMAGE
  ```
## Portal - View tag listings

- [dogfood portal](http://aka.ms/acr/portal/df)
- [wabbitnetworks tag listing](https://df.onecloud.azure-test.net/?Microsoft_Azure_ContainerRegistries=true#@MSFT.ccsctp.net/resource/subscriptions/f9d7ebed-adbd-4cb4-b973-aaf82c136138/resourceGroups/wabbitnetworks-acr/providers/Microsoft.ContainerRegistry/registries/wabbitnetworks/repository)

### Generate, Sign, Push SBoMs

- Push an SBoM
  ```bash
  echo '{"version": "0.0.0.0", "artifact": "'${IMAGE}'", "contents": "good"}' > sbom.json

  oras push $REPO \
    --artifact-type 'sbom/example' \
    --subject $IMAGE \
    -u $NOTATION_USERNAME -p $NOTATION_PASSWORD \
    ./sbom.json:application/json
  ```
- Sign the SBoM
  ```bash
  # Capture the digest, to sign it
  SBOM_DIGEST=$(oras discover -o json \
                  --artifact-type sbom/example \
                  -u $NOTATION_USERNAME -p $NOTATION_PASSWORD \
                  $IMAGE | jq -r ".references[0].digest")

  notation sign $REPO@$SBOM_DIGEST
  ```
- View the graph
  ```bash
  oras discover -o tree \
    -u $NOTATION_USERNAME -p $NOTATION_PASSWORD $IMAGE
  ```
### Generate, Sign, Push a Scan Result
- Scan the image, saving the results
  ```bash
  # Generate scan results with snyk
  docker scan --json $IMAGE > scan-results.json
  cat scan-results.json | jq
  ```
- Push the scan results to the registry, referencing the image
  ```bash
  
  oras push $REPO \
    --artifact-type application/vnd.org.snyk.results.v0 \
    --subject $IMAGE \
    -u $NOTATION_USERNAME -p $NOTATION_PASSWORD \
    scan-results.json:application/json
  ```
- Sign the scan results
  ```bash
  # Capture the digest, to sign the scan results
  SCAN_DIGEST=$(oras discover -o json \
                  --artifact-type application/vnd.org.snyk.results.v0 \
                  -u $NOTATION_USERNAME -p $NOTATION_PASSWORD \
                  $IMAGE | jq -r ".references[0].digest")

  notation sign $REPO@$SCAN_DIGEST

  oras discover -o tree -u $NOTATION_USERNAME -p $NOTATION_PASSWORD $IMAGE
  ```


## END DEMO


## Sign/Validate Recording
```bash
asciinema rec -t "notation in Azure" -i 2 --overwrite notation-in-azure.cast
sudo asciicast2gif -t tango notation-in-azure.cast notation-in-azure.gif
```
























## Import the Public Image

- The private registry is empty
  ```bash
  # Promote to a private registry
  # Nothing up the registries sleeves
  curl $PRIVATE_REGISTRY/v2/_catalog | jq
  ```
- Copy the graph of content from a source to destination registry/repo. ([See Copy Artifact Reference Graph #307](https://github.com/oras-project/oras/issues/307))  
The `net-monitor:v1` image will be ignored as the digest of the image manifest will already exist, however all the references that don't yet exist will be copied. Lastly a tag update will be applied as `oras cp` always copies the content before applying a tag update.
  ```bash
  oras cp -r $IMAGE $PRIVATE_IMAGE
  ```
- List the tags in the target repo
  ```bash
  # Only 1 tag, representing the one artifact
  curl $PRIVATE_REGISTRY/v2/net-monitor/tags/list | jq
  ```
- List the graph of artifacts for the `net-monitor:v1` image in the ACME Rockets registry
  ```bash
  # Discover the additional attributes
  oras discover -o tree $PRIVATE_IMAGE
  ```
- Filter the graph of artifacts for the `net-monitor:v1` to specific artifact types
  ```bash 
  # Discover the additional attributes, filtered by type
  oras discover -o tree \
    --artifact-type application/vnd.cncf.notary.v2.signature \
    $PRIVATE_IMAGE 
  ```

## Convert to gif
```bash
sudo asciicast2gif -t tango additional-objects.cast additional-objects.gif
docker run --rm -v $PWD:/data asciinema/asciicast2gif  additional-objects.cast additional-objects.gif
```

## Demo Reset

To resetting the environment

- Remove keys, certificates and notation `config.json`
  ```bash
  rm -r ~/.config/notation/
  ```
- Clear the images as this is our production vm
  ```bash
  docker rmi -f $(docker images -q)
  ```
- Clear the ACR repo
  ```bash
  az acr repository delete --repository net-monitor -y
  ```
- Edit `~/.config/notation/config.json` to support local, insecure registries
  ```bash
  mkdir ~/.config/notation
  echo '{"insecureRegistries": ["registry.wabbit-networks.io","localhost:5000"]}' > ~/.config/notation/config.json
  ```

