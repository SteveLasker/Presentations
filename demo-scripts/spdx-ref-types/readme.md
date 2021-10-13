# SPDX SBoMs and Reference Types

OCI Artifact Reference Types enables a graph of objects to be established, including signatures, Software Bill of Materials (SBoMs) and other artifact types.

## Demo Setup

Perform the following steps prior to the demo:

- Install [Docker Desktop](https://www.docker.com/products/docker-desktop) for local docker operations
- [Install Tern](https://github.com/tern-tools/tern#getting-started-on-linux) for generating an SPDX based SBoM
- [Install and Build nv2](../../building.md)
- [Install and Build the ORAS Prototype-2 branch](https://github.com/deislabs/oras/blob/prototype-2/docs/artifact-manifest.md)
- Generate the `~/.docker/nv2.json` config file
    ```bash
    docker nv2 notary --enabled
    ```
- Setup names and variables with `localhost:5000`
  >**NOTE:** See [Simulating a Registry DNS Name](#simulating-a-registry-dns-name) for using `registry.wabbit-networks.io`
  ```bash
  export PORT=5000
  export REGISTRY=localhost:${PORT}
  export REPO=${REGISTRY}/net-monitor
  export IMAGE=${REPO}:v1
  export PEPPER_IMAGE=${REPO}:pepper
  ```
- Generate the Wabbit Networks Public and Private Keys:
  ```bash
  openssl req \
    -x509 \
    -sha256 \
    -nodes \
    -newkey rsa:2048 \
    -days 365 \
    -subj "/CN=${REGISTRY}/O=wabbit-networks inc/C=US/ST=Washington/L=Seattle" \
    -addext "subjectAltName=DNS:${REGISTRY}" \
    -keyout ./wabbit-networks.key \
    -out ./wabbit-networks.crt
  ```

### Alias `nv2` Commands

- To avoid having to type `docker nv2` each time, create an alias:
  ```bash
  alias docker="docker nv2"
  ```
### Start a Local Registry Instance

  ```bash
  docker run -d -p ${PORT}:5000 notaryv2/registry:nv2-prototype-2
  ```

## Demo Script

1. Build the net-monitor image
    ```bash
    docker build \
      -t $IMAGE \
      https://github.com/wabbit-networks/net-monitor.git#main
    ```
1. Using Tern, generate an SPDX SBoM in `.json` format and view the file
    ```bash
    tern report -f spdxjson \
        -i $IMAGE \
        -o net-monitor_v1_spdx.json

    code net-monitor_v1_spdx.json
    ```
2. Push the netmonitor image to the registry
   ```
   docker push $IMAGE
   ```
3. Push the SBoM with ORAS. The manifest is locally saved for signing the SBOM
    ```
    oras push $REPO \
      --artifact-type org.spdx.sbom.v3 \
      --artifact-reference $IMAGE \
      --export-manifest net-monitor_v1_spdx-manifest.json \
      --plain-http \
      ./net-monitor_v1_spdx.json
    ```
4. Discover the SBOM, referenced to the `net-monitor:v1` image
    ```
    oras discover $IMAGE -o tree \
      --plain-http
    ```
5. Formatted as JSON
    ```
    oras discover $IMAGE -o json \
      --plain-http | jq
    ```

### Sign the SBoM

In the above case, the SBoM has already been pushed to the registry. To sign it before pushing, we could have used `oras push` with the `--dry-run` and `--export-manifest` options.

- For non-container images, we'll use the `nv2` cli to sign and  the `oras` cli to push to a registry. We'll use the `oras discover` cli to find the sbom digest the signature will reference.
  ```bash
  nv2 sign \
    -m x509 \
    -k wabbit-networks.key \
    -c wabbit-networks.crt \
    --plain-http \
    --push \
    --push-reference oci://${REPO}@$(oras discover \
      --artifact-type org.spdx.sbom.v3 \
      -o json \
      --plain-http \
      $IMAGE | jq -r .references[0].digest) \
    -o spdx-signature.json \
    file:net-monitor_v1_spdx-manifest.json
  ```
- Discover referenced artifacts of the SBoM
  ```bash
  oras discover $IMAGE -o tree \
    --plain-http
  ```
- Generates:
  ```bash
  registry.wabbit-networks.io/net-monitor:v1
  └── [org.spdx.sbom.v3]sha256:1f36ab761fb33f00f024218c8f8c4fc03984150c5217e3e6ef555f48089f88b1
      └── [application/vnd.cncf.notary.v2]sha256:a9b4a896c5e63a19279b0482c4cccde8ed616df14840e02cff13a8e3f04fa22d
  ```

## SPDX Tooling

1. Build the net-monitor image
    ```bash
    docker build \
      -t $IMAGE \
      https://github.com/wabbit-networks/net-monitor.git#main
    ```
2. Push the image
    ```bash
    docker push $IMAGE
    ```
3. Verify the image exists
   ```bash
   oras discover $IMAGE --plain-http -o tree
   ```
4. Create something to push to the registry
   ```bash
   echo "{something}" > something.json
   ```
5. Push a reference to the $IMAGE
    ```
    oras push $REPO \
      --artifact-type org.example.thing.v0 \
      --artifact-reference $IMAGE \
      ./something.json \
      --plain-http
    ```
3. Verify the image exists
   ```bash
   oras discover $IMAGE --plain-http -o tree
   ```
6. spdx push $IMAGE
    ```bash
    spdx push $IMAGE
    ```
1. Discover the referenced artfiacts
   ```bash
   oras discover $IMAGE --plain-http -o tree
   ```
2. List the references associated with $IMAGE
   ```
   spdx ls $IMAGE
   ```
3. SPDX Validate the $IMAGE
    ```
    spdx validate $IMAGE
    ```
4.  Do you have soup?

### Validate a policy where pepper is NOT allowed in your soup

1. Build the net-monitor `:pepper` image
    ```bash
    docker build \
      -t $PEPPER_IMAGE \
      https://github.com/wabbit-networks/net-monitor.git#pepper
    ```
1. Push the image
    ```bash
    docker push $PEPPER_IMAGE
    ```
1. spdx push $PEPPER_IMAGE
    ```bash
    spdx push $PEPPER_IMAGE
    ```
1. List the references associated with $IMAGE
   ```
   spdx ls $PEPPER_IMAGE
   ```
1. SPDX Validate the $PEPPER_IMAGE
    ```
    spdx validate $PEPPER_IMAGE
    ```
1. Do you have soup?


### Simulating a Registry DNS Name

Configure the additional steps to simulate a fully qualified dns name for wabbit-networks.

- Setup names and variables with `registry.wabbit-networks.io`
  ```bash
  export PORT=80
  export REGISTRY=registry.wabbit-networks.io
  export REPO=${REGISTRY}/net-monitor
  export IMAGE=${REPO}:v1
  ```
- Edit the `~/.docker/nv2.json` file to support local, insecure registries
  ```json
  {
    "enabled": true,
    "verificationCerts": [
    ],
    "insecureRegistries": [
      "registry.wabbit-networks.io"
    ]
  }
  ```
- Add a `etc/hosts` entry to simulate pushing to registry.wabbit-networks.io
  - If running on windows, _even if using wsl_, add the following entry to: `C:\Windows\System32\drivers\etc\hosts`
    ```hosts
    127.0.0.1 registry.wabbit-networks.io
    ```
- Continue with [Start a Local Registry Instance](#start-a-local-registry-instance)

### SPDX

export PORT=80
export REGISTRY=registry.wabbit-networks.io
export REPO=${REGISTRY}/net-monitor
export IMAGE=${REPO}:v1
export PEPPER_IMAGE=${REPO}:pepper

spdx push $IMAGE

/ spdx push does:
- generates the SPDX document with `tern report` (shell out to the tern cli, assuming it's on disk)
- signs the spdx.json output
- pushes both the spdx artifact and the nv2 signature to the registry

spdx ls $IMAGE
- list the SPDX documents for the image
- tree of signatures
- equivalent to `oras discover artifact-type=org.spdx.v3 -o tree`

1. oras binary
2. change the default artifactType = org.spdx.v3, with layer mediaTypes of application/tar
3. internally, shell out to tern report
4. push as an artifact.manifest, with the subjectManifest = $IMAGE digest
5. push an nv2 signature

Add a validate command
return "soup for you"


[oci-artifact-manifest-spec]:   https://github.com/SteveLasker/artifacts/blob/oci-artifact-manifest/artifact-manifest-spec.md
[oci-artifact-manifest]:        https://github.com/SteveLasker/artifacts/blob/oci-artifact-manifest/artifact-manifest.md
[notary-v2-project]:            https://github.com/notaryproject/notaryproject