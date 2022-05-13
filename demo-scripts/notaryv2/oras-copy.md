# Promoting Artifacts - KubeCon 2021

Builds on [nv2-acr-gif.md](nv2-acr-gif.md)

## Getting Started
- Setup a few environment variables.  
  ```bash
  export PUBLIC_PORT=5000
  export PUBLIC_REGISTRY=localhost:${PUBLIC_PORT}
  export PUBLIC_REPO=${PUBLIC_REGISTRY}/net-monitor
  export PUBLIC_IMAGE=${PUBLIC_REPO}:v1

  export PRIVATE_PORT=5050
  export PRIVATE_REGISTRY=localhost:${PRIVATE_PORT}
  export PRIVATE_REPO=${PRIVATE_REGISTRY}/net-monitor
  export PRIVATE_IMAGE=${PRIVATE_REPO}:v1
  ```
- Run a local registry representing the Wabbit Networks **public** registry
- Run a local registry representing the ACME Rockets **private** registry
  ```bash
  docker run -d -p ${PUBLIC_PORT}:5000 ghcr.io/oras-project/registry:latest
  docker run -d -p ${PRIVATE_PORT}:5000 ghcr.io/oras-project/registry:latest
  ```

## Prep the content, similar to acr
  ```bash
  docker build -t $PUBLIC_IMAGE https://github.com/wabbit-networks/net-monitor.git#main
  docker push $PUBLIC_IMAGE
  ```
- Generate a test certificate
  ```bash
  # Generate a test certificate
  notation cert generate-test "wabbit-networks.io"
  ```
- Sign the container image
  ```bash
  notation sign -k "wabbit-networks.io" $PUBLIC_IMAGE
  ```
- Create a test cert for the ACME Rockets Library key
  ```bash
  # Generate the ACME Rockets key, for signing within ACME Rockets
  notation cert generate-test "acme-rockets.io-library"
  ```
- Sign the container image
  ```bash
  notation sign -k "acme-rockets.io-library" $PUBLIC_IMAGE
  ```
-- Push an SBoM
  ```bash
  echo '{"version": "0.0.0.0", "artifact": "'${PUBLIC_IMAGE}'", "contents": "good"}' > sbom.json
  oras push $PUBLIC_REPO \
    --artifact-type sbom/example \
    --subject $PUBLIC_IMAGE \
    sbom.json:application/json
  ```
- Sign the SBoM
  ```bash
  notation sign -k "acme-rockets.io-library" \
  $PUBLIC_REPO@$(oras discover -o json \
                  --artifact-type sbom/example \
                  $PUBLIC_IMAGE | jq -r ".references[0].digest")
  ```
- Scan the image, saving the results
  ```bash
  docker scan --json $PUBLIC_IMAGE > scan-results.json
  ```
- Push the scan results to the registry, referencing the image
  ```bash
  oras push $PUBLIC_REPO \
    --artifact-type application/vnd.org.snyk.results.v0 \
    --subject $PUBLIC_IMAGE \
    scan-results.json:application/json
  ```
- Sign the scan results
  ```bash
  notation sign -k "acme-rockets.io-library" \
    $PUBLIC_REPO@$(oras discover -o json \
                  --artifact-type application/vnd.org.snyk.results.v0 \
                  $PUBLIC_IMAGE | jq -r ".references[0].digest")
  ```
- View the graph
  ```bash
  oras discover -o tree $PUBLIC_IMAGE
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

## Demo Reset

``` bash
# REMOVE THE PRIVATE REGISTRY PORT 5050
docker rm -f PORT_5050_IMAGE
docker run -d -p ${PRIVATE_PORT}:5000 ghcr.io/oras-project/registry:latest

rm -r ~/.config/notation/

mkdir ~/.config/notation
echo '{"insecureRegistries": ["registry.wabbit-networks.io","localhost:5000","localhost:5050"]}' > ~/.config/notation/config.json
```

[notation-releases]:      https://github.com/shizhMSFT/notation/releases/tag/v0.5.0
[artifact-manifest]:      https://github.com/oras-project/artifacts-spec/blob/main/artifact-manifest.md
[cncf-distribution]:      https://github.com/oras-project/distribution