# Promoting Artifacts - KubeCon 2021

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
- Install [Docker Desktop](https://www.docker.com/products/docker-desktop) for local docker operations
- Install [ORAS with the copy command](https://github.com/juliusl/oras/releases/tag/v0.11.22-alpha)
- Run a local registry representing the Wabbit Networks **public** registry
  ```bash
  docker run -d -p ${PUBLIC_PORT}:5000 ghcr.io/oras-project/registry:latest
  ```
- Run a local registry representing the ACME Rockets **private** registry
  ```bash
  docker run -d -p ${PRIVATE_PORT}:5000 ghcr.io/oras-project/registry:latest
  ```
## Generate Keys
- Generate a self-signed test certificate for signing artifacts
  The following will generate a self-signed X.509 certificate under the `~/config/notation/` directory
  ```bash
  notation cert generate-test \
    --default "wabbit-networks.io"
  ```

## Building and Pushing the Public Image
- Build and push the `net-monitor` software
  ```bash
  docker build -t $PUBLIC_IMAGE https://github.com/wabbit-networks/net-monitor.git#main
  docker push $PUBLIC_IMAGE
  ```
- Sign the container image
  ```bash
  notation sign $PUBLIC_IMAGE
  ```
- List the image, and any associated signatures
  ```bash
  notation list $PUBLIC_IMAGE
  oras discover -o tree $PUBLIC_IMAGE
  ```
## Generate, Sign, Push SBoMs
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
  SBOM_DIGEST=$(oras discover -o json \
                  --artifact-type sbom/example \
                  $PUBLIC_IMAGE | jq -r ".references[0].digest")

  notation sign $PUBLIC_REPO@$SBOM_DIGEST
  ```
- View the graph
  ```bash
  oras discover -o tree $PUBLIC_IMAGE
  ```
## Generate, Sign, Push a Scan Result
- Scan the image, saving the results
  ```bash
  docker scan --json $PUBLIC_IMAGE > scan-results.json
  cat scan-results.json | jq
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
  SCAN_DIGEST=$(oras discover -o json \
                  --artifact-type application/vnd.org.snyk.results.v0 \
                  $PUBLIC_IMAGE | jq -r ".references[0].digest")

  notation sign $PUBLIC_REPO@$SCAN_DIGEST

  oras discover -o tree $PUBLIC_IMAGE
  ```
## Back to Slides

Setup promotion w/copy semantics

## Import the Public Image

- The private registry is empty
  ```bash
  curl $PRIVATE_REGISTRY/v2/_catalog | jq
  ```
- Validate the image is signed with a key that fits within the ACME Rockets policy
  ```bash
  notation verify $PUBLIC_IMAGE
  ```
- The above command should fail, as the Wabbit Networks public key has not yet been configured
- Configure the Wabbit Networks key for validation, and re-validate
  ```bash
  notation cert add -n "wabbit-networks.io" \
    ~/.config/notation/certificate/wabbit-networks.io.crt
  notation verify $PUBLIC_IMAGE
  ``` 
- Create a test cert for the ACME Rockets Library key
  ```bash
  notation cert generate-test \
    --trust --default \
    "acme-rockets.io-library"
  ```
- To support tag update scenarios, the image must be signed with a new signature and pushed with all artifact references
- Sign the imported image, locally
  ```bash
  docker pull $PUBLIC_IMAGE
  docker tag $PUBLIC_IMAGE $PRIVATE_IMAGE
  docker push $PRIVATE_IMAGE
  notation sign $PRIVATE_IMAGE
  ```
- View the current graph in the private registry
  ```bash
  oras discover -o tree $PRIVATE_IMAGE
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
  oras discover -o tree \
  $PRIVATE_IMAGE
  ```
- Filter the graph of artifacts for the `net-monitor:v1` to specific artifact types
  ```bash 
  oras discover -o tree \
    --artifact-type org.cncf.notary.v2 \
    $PRIVATE_IMAGE 
  ```

## Demo Reset

``` bash
docker rm -f $(docker ps -q)
rm ~/.config/notation/certificate/*.*
rm ~/.config/notation/key/*.*
# remove keys, certs and default entries
code ~/.config/notation/config.json
```
`config.json` Should look like:
```json
{
	"insecureRegistries": [
		"localhost:5000",
		"localhost:5050"
	]
}
```

[notation-releases]:      https://github.com/shizhMSFT/notation/releases/tag/v0.5.0
[artifact-manifest]:      https://github.com/oras-project/artifacts-spec/blob/main/artifact-manifest.md
[cncf-distribution]:      https://github.com/oras-project/distribution