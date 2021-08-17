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
    oras discover \
      --plain-http \
      $IMAGE
    ```
5. Formatted as JSON
    ```
    oras discover \
      --plain-http \
      $IMAGE \
      --output-json|jq
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
      --output-json \
      --plain-http \
      $IMAGE | jq -r .references[0].digest) \
    file:net-monitor_v1_spdx-manifest.json
  ```
- Dynamically get the SBoM digest
  ```bash
  DIGEST=$(oras discover \
      --artifact-type org.spdx.sbom.v3 \
      --output-json \
      --plain-http \
      $IMAGE | jq -r .references[0].digest)
- Discover referenced artifacts of the SBoM
  ```bash
  oras discover \
    --plain-http \
    ${REPO}@${DIGEST} \
    --output-json|jq
  ```
- Generates:
  ```bash
  Discovered 1 artifacts referencing localhost:5000/net-monitor@sha256:adfe3a3c50838fc2a19d5d7e73119dcadad7ad8e4e98f1e0fd100dd9d2278b71
  Digest: sha256:adfe3a3c50838fc2a19d5d7e73119dcadad7ad8e4e98f1e0fd100dd9d2278b71

  Artifact Type                    Digest
  application/vnd.cncf.notary.v2   sha256:b7fc5fdb81f2ada359d0a709004360d1f08c9d2ac8a80630b152d1c6fb35460e
  ```

The above workflow demonstrates the **Notary v2, prototype-2** target experience.

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

[oci-artifact-manifest-spec]:   https://github.com/SteveLasker/artifacts/blob/oci-artifact-manifest/artifact-manifest-spec.md
[oci-artifact-manifest]:        https://github.com/SteveLasker/artifacts/blob/oci-artifact-manifest/artifact-manifest.md
[notary-v2-project]:            https://github.com/notaryproject/notaryproject