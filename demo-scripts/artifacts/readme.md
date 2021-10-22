# ORAS Artifacts - Supply Chain Artifact Support

ORAS Artifacts supports reference types,  enabling a graph of objects to be established, including signatures, Software Bill of Materials (SBoMs) and other artifact types.
![](https://raw.githubusercontent.com/oras-project/artifacts-spec/main/media/net-monitor-graph.svg)

## Getting Started

- Setup a few environment variables.  
  > Note see [Simulating a Registry DNS Name](#simulating-a-registry-dns-name) to use `registry.wabbit-networks.io` as the registry name.
  ```bash
  export PORT=5000
  export REGISTRY=localhost:${PORT}
  export REPO=net-monitor
  export IMAGE=${REGISTRY}/${REPO}:v1
  ```
- Install [Docker Desktop](https://www.docker.com/products/docker-desktop) for local docker operations
- Run a local instance of the [CNCF Distribution Registry][cncf-distribution]
  ```bash
  docker run -d -p ${PORT}:5000 ghcr.io/oras-project/registry:latest
  ```
- Acquire the ORAS CLI  
ORAS releases can be found at: [oras releases][oras-releases]  
  ```bash
  #LINUX, including WSL
  curl -LO https://github.com/sajayantony/oras/releases/download/v0.5.4-alpha/oras_0.5.4-alpha_linux_amd64.tar.gz
  mkdir oras
  tar -xvf ./oras_0.5.4-alpha_linux_amd64.tar.gz -C ./oras/
  cp ./oras/oras ~/bin/oras
  ```
## Building and Pushing

- Build and Push $IMAGE
  ```bash
  docker build -t $IMAGE https://github.com/wabbit-networks/net-monitor.git#main

  docker push $IMAGE
  ```
- List the repositories
  ```http
  curl $REGISTRY/v2/_catalog | jq
  ```
- List the tags, to see a focused list of content on the artifacts users rationalize
  ```http
  curl $REGISTRY/v2/$REPO/tags/list | jq
  ```
## Push an SBoM and a Scan Result which References $IMAGE

- Clone some sample documents
  ```bash
  git clone https://github.com/SteveLasker/demo-oci-artifact-referenceTypes.git
  cd demo-oci-artifact-referenceTypes/sample-artifacts
  ```
- Push the SBoM, referencing $IMAGE
  ```shell
  oras push $REGISTRY/$REPO \
      --artifact-type sbom/example \
      --subject $IMAGE \
      --plain-http \
      sbom.json:application/json
  ```
- Push a security scan result, referencing $IMAGE
  ```shell
  oras push $REGISTRY/$REPO \
      --artifact-type scan-result/example \
      --subject $IMAGE \
      --plain-http \
      scan-results.xml:application/xml
  ```
- List the tags, notice the additional metadata doesn't pollute the tag listing
  ```http
  curl $REGISTRY/v2/$REPO/tags/list | jq
  ```
## Discovering Artifact References

To find the list of artifacts that reference a `subject` artifact (such as a container image), the artifacts-spec provides a `/referrers/` API

- Get the digest of the $IMAGE
  ```bash
  DIGEST=$(oras discover $IMAGE --plain-http -o json | jq -r .digest)
  ```
- Get the artifacts that reference $IMAGE with the artifacts-spec `/referrers/` API
  ```http
  curl $REGISTRY/oras/artifacts/v1/net-monitor/manifests/$DIGEST/referrers | jq
  ```
- Get a filtered list by `artifactType`
  ```http
  curl $REGISTRY/oras/artifacts/v1/net-monitor/manifests/$DIGEST/referrers?artifactType=sbom%2Fexample | jq
  ```
- `oras discover` provides a cli to list all, or specific artifact references.
  ```bash
  oras discover -o tree --plain-http $IMAGE
  ```

## Pulling Artifact References

Pulling an artifact is the same `oras pull`. The difference is we need to specify the digest of the referenced artifact.

- Create a directory
  ```bash
  mkdir download
  ```
- Pull a signature artifact by embedding `oras discover`
  ```shell
  oras pull -a --plain-http \
    -o ./download/ \
      ${REGISTRY}/${REPO}@$( \
        oras discover --plain-http \
          -o json \
          --artifact-type scan-result/example \
          $IMAGE | jq -r .references[0].digest)

  ls ./download/
  ```
## Demo Reset
```bash
docker rm -f $(docker ps -q)
```
## Simulating a Registry DNS Name

Here are the additional steps to simulate a fully qualified DNS name for `wabbit-networks`.

- Setup names and variables for `registry.wabbit-networks.io`
  ```bash
  export PORT=80
  export REGISTRY=registry.wabbit-networks.io
  export REPO=net-monitor
  export IMAGE=${REGISTRY}/${REPO}:v1
  ```
- Add a `etc/hosts` entry to simulate pushing to registry.wabbit-networks.io
    - If running on windows, _even if using wsl_, add the following entry to: `C:\Windows\System32\drivers\etc\hosts`
      ```hosts
      127.0.0.1 registry.wabbit-networks.io
      ```
- Continue with [Getting Started](#getting-started), but skip the environment variable configurations

For more information see the [oci.artifact.manifest][oci-artifact-manifest] overview for various scenarios and usage.

[oras-releases]:                https://github.com/sajayantony/oras/releases
[cncf-distribution]:      https://github.com/oras-project/distribution
[oci-artifact-manifest-spec]:   https://github.com/SteveLasker/artifacts/blob/oci-artifact-manifest/artifact-manifest-spec.md
[oci-artifact-manifest]:        https://github.com/SteveLasker/artifacts/blob/oci-artifact-manifest/artifact-manifest.md
[notary-v2-project]:            https://github.com/notaryproject/notaryproject
