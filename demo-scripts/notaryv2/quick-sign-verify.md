# Notary v2 Quick Sign/Verify Demo

## Preset
```bash
export PORT=5000
export REGISTRY=localhost:${PORT}
export REPO=${REGISTRY}/net-monitor
export IMAGE=${REPO}:v1

docker run -d -p ${PORT}:5000 ghcr.io/oras-project/registry:v0.0.3-alpha

docker build -t $IMAGE https://github.com/wabbit-networks/net-monitor.git#main
docker push $IMAGE
```

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
    --artifact-type sbom/example \
    --subject $IMAGE \
    sbom.json:application/json
  ```
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

