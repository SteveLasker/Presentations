# Notary v2 Quick Sign/Verify Demo

## Preset

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


# Create an ACR
# Premium to use tokens
az group create -l $REGION -n $ACR_RG
az acr create -n $ACR_NAME -g $ACR_NAME-acr --sku Premium
az acr update -n wabbitnetworks --anonymous-pull-enabled true

# Using ACR Auth with Tokens
export USERNAME='my-token'
export PASSWORD=$(az acr token create -n $USERNAME \
                    -r $ACR_NAME \
                    --scope-map _repositories_admin \
                    --only-show-errors \
                    -o json | jq -r ".credentials.passwords[0].value")
docker login -u $USERNAME -p $PASSWORD $REGISTRY
oras login -u $USERNAME -p $PASSWORD $REGISTRY

docker build -t $IMAGE https://github.com/wabbit-networks/net-monitor.git#main
docker push $IMAGE

oras discover -o tree $IMAGE

# Name of the Azure Key Vault used to store the signing keys
AKV_NAME=wabbitnetworks
# Key name used to sign and verify
KEY_NAME=wabbit-networks-io
KEY_SUBJECT_NAME=wabbit-networks.io
# Name of the AKV Resource Group
AKV_RG=${AKV_NAME}-akv-rg


## Demo

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
  notation list $IMAGE
  ```
- Verify the image, but no are yet keys are configured
  ```bash
  # Validation fails, as there are no public keys configured
  notation verify $IMAGE
  ```
- Configure a key for validation
  ```bash
  notation cert add --name "wabbit-networks.io" \
    ~/.config/notation/certificate/wabbit-networks.io.crt
  ```
- Re-verify, with a configured key
  ```bash
  notation verify $IMAGE
  ```
- View the graph
  ```bash
  oras discover -o tree $IMAGE
  ```
## Sign/Validate Recording
```bash
asciinema rec -t "notation quick-start" -i 2 --overwrite sign-verify.cast
sudo asciicast2gif -t tango sign-verify.cast sign-verify.gif
docker run --rm -v $PWD:/data asciinema/asciicast2gif  sign-verify.cast sign-verify.gif
asciicas
```

## Publish Additional Objects
- Setup a few environment variables.  
  ```bash
  export PRIVATE_PORT=5050
  export PRIVATE_REGISTRY=localhost:${PRIVATE_PORT}
  export PRIVATE_REPO=${PRIVATE_REGISTRY}/net-monitor
  export PRIVATE_IMAGE=${PRIVATE_REPO}:v1
  ```
- Run a local registry representing the ACME Rockets **private** registry
  ```bash
  docker run -d -p ${PRIVATE_PORT}:5000 ghcr.io/oras-project/registry:latest
  ```
### Start the recording

```bash
asciinema rec -t "notation additional supply chain objects" -i 2 --overwrite additional-objects.cast
```
### Generate, Sign, Push SBoMs

- List the image, and any associated signatures
  ```bash
  # What artifacts do we currently have
  oras discover -o tree $IMAGE
  ```

- Push an SBoM
  ```bash
  echo '{"version": "0.0.0.0", "artifact": "'${IMAGE}'", "contents": "good"}' > sbom.json

  oras push $REPO \
    --artifact-type 'sbom/example' \
    --subject $IMAGE \
    ./sbom.json:application/json -v
  ```
oras push $REPO:vN \
    -u $NOTATION_USERNAME -p $NOTATION_PASSWORD \
    --manifest-config /dev/null:application/vnd.unknown.config.v1+json \
    ./config.json:application/vnd.unknown.layer.v1+txt


- Sign the SBoM
  ```bash
  # Capture the digest, to sign it
  SBOM_DIGEST=$(oras discover -o json \
                  --artifact-type sbom/example \
                  $IMAGE | jq -r ".references[0].digest")

  notation sign $REPO@$SBOM_DIGEST
  ```
- View the graph
  ```bash
  oras discover -o tree $IMAGE
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
    scan-results.json:application/json
  ```
- Sign the scan results
  ```bash
  # Capture the digest, to sign the scan results
  SCAN_DIGEST=$(oras discover -o json \
                  --artifact-type application/vnd.org.snyk.results.v0 \
                  $IMAGE | jq -r ".references[0].digest")

  notation sign $REPO@$SCAN_DIGEST

  oras discover -o tree $IMAGE
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
  - `rm -r ~/.config/notation/`
- Restart the local registry docker
  - `docker rm -f $(docker ps -q)`
- Edit `~/.config/notation/config.json` to support local, insecure registries
  ```bash
  mkdir ~/.config/notation
  echo '{"insecureRegistries": ["registry.wabbit-networks.io","localhost:5000"]}' > ~/.config/notation/config.json
  ```



echo 'com.microsoft.policy=sdl' > annotations.txt
echo 'policy=sdl' > annotations.txt

echo '{"$manifest": {"com.microsoft.policy": "sdl"}}' > annotations.json

oras push $REGISTRY/$REPO \
    --artifact-type 'signature/example' \
    --subject $IMAGE \
    --manifest-annotations annotations.txt \
    ./signature.json:application/json


cat <<EOF > ./claims.json
{
  "version": "0.0.0.0",
  "subject": "'${IMAGE}'",
  "com.company.policy": "level3",
  "io.something.policy.foobar": "true"
}
EOF

oras push $REGISTRY/$REPO \
    --artifact-type 'application/vnd.ietf.scitt.v1' \
    --subject $IMAGE \
    --manifest-annotations annotations.json \
    ./claims.json:application/json

CLAIMS_DIGEST=$(oras discover -o json \
                  --artifact-type application/vnd.ietf.scitt.v1 \
                  $IMAGE | jq -r ".references[0].digest")

az acr manifest show -r $ACR_NAME -n net-monitor@$CLAIMS_DIGEST -o jsonc

oras pull -a -o ./download $REGISTRY/$REPO@$CLAIMS_DIGEST
