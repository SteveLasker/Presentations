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
az configure --default acr=$ACR_NAME
az acr update --anonymous-pull-enabled true

# Using ACR Auth with Tokens
export NOTATION_USERNAME=$ACR_NAME'-token'
export NOTATION_PASSWORD=$(az acr token create -n $NOTATION_USERNAME \
                    -r $ACR_NAME \
                    --scope-map _repositories_admin \
                    --only-show-errors \
                    -o json | jq -r ".credentials.passwords[0].value")

docker login $REGISTRY -u $NOTATION_USERNAME -p $NOTATION_PASSWORD
```
## Binaries

### notation

```bash
curl -Lo notation.tar.gz https://github.com/shizhMSFT/notation/releases/download/v0.7.0-shizh.2/notation_0.7.0-shizh.2_linux_amd64.tar.gz

tar xvzf notation.tar.gz -C ~/bin notation
```

### oras

```bash
curl -Lo oras.tar.gz https://github.com/shizhMSFT/oras/releases/download/v0.11.1-shizh.1/oras_0.11.1-shizh.1_linux_amd64.tar.gz
tar xvzf oras.tar.gz -C ~/bin oras
```

## Sign/Validate Recording
```bash
asciinema rec -t "notation in Azure" -i 2 --overwrite notation-in-azure.cast
sudo asciicast2gif -t tango notation-in-azure.cast notation-in-azure.gif
```

## Demo

- View the [Azure Portal](https://aka.ms/acr/portal/df)

- We'll build, push, sign, SBOM, scan and sign again, in Azure
  ```bash
  # We'll build, push, sign, SBOM, scan and sign again, in Azure
  echo $IMAGE
  ```
echo $IMAGE
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
  oras discover \
    -u $NOTATION_USERNAME -p $NOTATION_PASSWORD \
    -o tree $IMAGE
  ```
- View the tags
  ```bash
  # View the list of artifacts we want to think about
  az acr repository show-tags \
    --repository net-monitor -o jsonc
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
  az acr repository show-manifests \
    -n wabbitnetworks --repository net-monitor \
    --detail -o jsonc
  ```
## Second Signature/Promotion
- Clear the images as this is our production vm
  ```bash
  # Create an Ephemeral Environment
  docker rmi -f $(docker images -q)
  ```
- List the images 
  ```bash
  docker images -a
  ```
- Clear the configuration policy
  ```bash
  # Clear the configuration policy
  rm -r ~/.config/notation/
  ```
- Create a test cert for the ACME Rockets Library key
  ```bash
  # Generate the ACME Rockets key, for signing within ACME Rockets
  notation cert generate-test \
    --default \
    "acme-rockets.io-library"
  ```
- View the configuration policy
  ```bash
  # View the configuration policy
  cat ~/.config/notation/config.json | jq
  ```
- Attempt to validate with the ACME Rockets key
  ```bash
  # Attempt to validate with the ACME Rockets key
  # It fails, as the image isn't signed with the key
  notation verify $IMAGE
  ```
- Sign the image with the Production cert
  ```bash
  notation sign $IMAGE
  ```
- Configure the ACME Rockets key for validation
  ```bash
  # Add the ACME Rockets key to the config policy
  notation cert add --name "acme-rockets.io-library" \
    ~/.config/notation/certificate/acme-rockets.io-library.crt
  ```
- Validate with the ACME Rockets key
  ```bash
  # Now, the image can be pulled
  notation verify $IMAGE
  ```
- View the graph
  ```bash
  # View the graph of artifacts
  oras discover \
      -u $NOTATION_USERNAME -p $NOTATION_PASSWORD \
      -o tree $IMAGE
    ```
## Portal - View tag listings

- [dogfood portal](http://aka.ms/acr/portal/df)

### Generate, Sign, Push SBoMs

- Push an SBoM
  ```bash
  # But wait, there's more
  # Let's push an SBOM, Scan Result and sign them 
  # creating a self contained graph of supply chain content

  # Create, Push and sign the SBoM
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
  # View the graph
  oras discover \
      -u $NOTATION_USERNAME -p $NOTATION_PASSWORD \
      -o tree $IMAGE
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
  # Push the Snyk Scan Results
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

  # We now have a full self-described graph of
  oras discover \
    -u $NOTATION_USERNAME -p $NOTATION_PASSWORD \
    -o tree $IMAGE
  ```
- View a filtered graph
  ```bash
  oras discover \
    --artifact-type "application/vnd.cncf.notary.v2.signature" \
    -u $NOTATION_USERNAME -p $NOTATION_PASSWORD \
    -o tree $IMAGE
  ```
## Import the Public Image

- The private registry is empty
  ```bash
  curl $PRIVATE_REGISTRY/v2/_catalog | jq
  ```
- Copy the graph of content from a source to destination registry/repo. ([See Copy Artifact Reference Graph #307](https://github.com/oras-project/oras/issues/307))  
The `net-monitor:v1` image will be ignored as the digest of the image manifest will already exist, however all the references that don't yet exist will be copied. Lastly a tag update will be applied as `oras cp` always copies the content before applying a tag update.
  ```bash
  oras cp -r $PUBLIC_IMAGE $PRIVATE_IMAGE
  ```
- List the repos in the target registry
  ```bash
  curl $PRIVATE_REGISTRY/v2/_catalog | jq
  ```
- List the tags in the target repo
  ```bash
  curl $PRIVATE_REGISTRY/v2/net-monitor/tags/list | jq
  ```
- List the graph of artifacts for the `net-monitor:v1` image in the ACME Rockets registry
  ```bash 
  oras discover -o tree $PRIVATE_IMAGE
  ```
- Filter the graph of artifacts for the `net-monitor:v1` to specific artifact types
  ```bash 
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
  echo '{"insecureRegistries": ["registry.wabbit-networks.io","localhost:5000","localhost:5050"]}' > ~/.config/notation/config.json
  ```

