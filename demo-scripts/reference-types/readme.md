# OCI Artifact Manifest Reference Types

OCI Artifact Reference Types enables a graph of objects to be established, including signatures, Software Bill of Materials (SBoMs) and other artifact types.

## Building the Experimental Branch

- Build the `oci-artifact.manifest` experimental branch:
  ```bash
  git clone https://github.com/deislabs/oras.git
  cd oras
  git checkout prototype-2
  make build
  ```
- Copy `oras` to a central location for easy reference
  ```bash
  # linux, including wsl:
  sudo cp ./bin/linux/amd64/oras /usr/local/bin/oras
  ```
- Verify the additional `discover` command, confirming the experimental branch
  ```bash
  oras --help
  Usage:
    oras [command]

  Available Commands:
    discover    discover artifacts from remote registry
    help        Help about any command
    login       Log in to a remote registry
    logout      Log out from a remote registry
    pull        Pull files from remote registry
    push        Push files to remote registry
    version     Show the oras version information
  ```

See the [developers guide](../BUILDING.md) for more details on building `oras`

## Running Distribution with OCI Artifact Manifest Support

Run a local instance of distribution, with `oci.artifact.manifest` support. The image is built from: [notaryproject/distribution/tree/prototype-2](https://github.com/notaryproject/distribution/tree/prototype-2)
> Note: this is a temporary location as oci.artifact.manifest is being developed under the [Notary v2][notary-v2-project] project.

```bash
docker run -it -p 5000:5000 \
  --name oci-artifact-registry \
  notaryv2/registry:nv2-prototype-2
docker run -d -p 5000:5000 notaryv2/registry:nv2-prototype-2
```
## Sample Artifact Types

- Clone some sample documents
  ```bash
  git clone https://github.com/SteveLasker/demo-oci-artifact-referenceTypes.git
  ```
## Push a Target Image Artifact

- Push `hello-world:latest` to the locally instanced registry:
  ```bash
  docker pull hello-world:latest 
  docker tag hello-world:latest localhost:5000/hello-world:latest
  docker push localhost:5000/hello-world:latest
  ```
## Push an SBoM as reference type

- Push the SBoM, referencing the `hello-world:latest` image:
  ```shell
  oras push localhost:5000/hello-world \
      --artifact-type x.example.sbom.v0 \
      --artifact-reference localhost:5000/hello-world:latest \
      sbom.json:application/json
  ```
- Generates output:
  ```shell
  Uploading 204e7c423c89 sbom.json
  Pushed localhost:5000/hello-world
  Digest: sha256:f4232599e2d5246ec1f4dc419bacd5510a02c2f0e3c98b800f38c8cbbd61550d
  ```

## Discovering Artifact References

To find the list of artifacts that reference a target artifact (such as a container image), the `oras discover` api provides a quick means to list all, or specific artifact references.

- Discover the artifacts which reference `localhost:5000/hello-world:latest`
  ```
  oras discover --output-json localhost:5000/hello-world:latest | jq
  ```
- Generates output:
  ```json
  {
    "digest": "sha256:1b26826f602946860c279fce658f31050cff2c596583af237d971f4629b57792",
    "references": [
      {
        "digest": "sha256:fa31146981940964ced259bd2edd36c10277207e3be4d161bdb96e5e418fc2e0",
        "manifest": {
          "schemaVersion": 2,
          "mediaType": "application/vnd.oci.artifact.manifest.v1+json",
          "artifactType": "application/x.example.sbom.v0",
          "blobs": [
            {
              "mediaType": "application/tar",
              "digest": "sha256:204e7c423c891d0e4b057c4ecb068a53ffc991ef5a3bb47467f1b8088775dc48",
              "size": 84
            }
          ],
          "manifests": [
            {
              "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
              "digest": "sha256:1b26826f602946860c279fce658f31050cff2c596583af237d971f4629b57792",
              "size": 525
            }
          ]
        }
      }
    ]
  }
  ```

## Discovering Artifacts with `artifactType` Filtering

- Push the signature, referencing the `hello-world:latest` image:
  ```shell
  oras push localhost:5000/hello-world \
      --artifact-type application/x.example.signature.v0 \
      --artifact-reference localhost:5000/hello-world:latest \
      signature.json:application/json
  ```

- Discover all artifacts which reference `localhost:5000/hello-world:latest`
  ```
  oras discover \
    --output-json \
    localhost:5000/hello-world:latest | jq
  ```

- Discover the artifacts which reference `localhost:5000/hello-world:latest`, filtered by `application/x.example.signature.v0`
  ```
  oras discover \
    --output-json \
    --artifact-type application/x.example.signature.v0 \
    localhost:5000/hello-world:latest | jq
  ```

- Generates output:
  ```json
  {
    "digest": "sha256:1b26826f602946860c279fce658f31050cff2c596583af237d971f4629b57792",
    "references": [
      {
        "digest": "sha256:c5fbdddecc83f1af8743983ce114452b856b77e92a5c7f4075c0110ea1e35e38",
        "manifest": {
          "schemaVersion": 2,
          "mediaType": "application/vnd.oci.artifact.manifest.v1+json",
          "artifactType": "application/x.example.signature.v0",
          "blobs": [
            {
              "mediaType": "application/tar",
              "digest": "sha256:01aafb7acd80d5d25c7619b2d7ddd4912434f58dec3e479b822197fd8a385552",
              "size": 91
            }
          ],
          "manifests": [
            {
              "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
              "digest": "sha256:1b26826f602946860c279fce658f31050cff2c596583af237d971f4629b57792",
              "size": 525
            }
          ]
        }
      }
    ]
  }
  ```

> Note: see [issue #255](https://github.com/deislabs/oras/issues/255) for `default` and `--verbose` output options

## Pulling Artifact References

Pulling an artifact is the same as the regular `oras pull`. This example 

- Pull a signature artifact by embedding `oras discover`
  ```shell
  oras pull -a \
      localhost:5000/hello-world@$( \
        oras discover \
          --output-json \
          --artifact-type application/x.example.signature.v0 \
          localhost:5000/hello-world:latest | jq -r .references[0].digest)
  ```

- Generates output:
  ```
  Downloaded 01aafb7acd80 signature.json
  Pulled localhost:5000/hello-world@sha256:c5fbdddecc83f1af8743983ce114452b856b77e92a5c7f4075c0110ea1e35e38
  Digest: sha256:c5fbdddecc83f1af8743983ce114452b856b77e92a5c7f4075c0110ea1e35e38
  ```

For more information see the [oci.artifact.manifest][oci-artifact-manifest] overview for various scenarios and usage.

[oci-artifact-manifest-spec]:   https://github.com/SteveLasker/artifacts/blob/oci-artifact-manifest/artifact-manifest-spec.md
[oci-artifact-manifest]:        https://github.com/SteveLasker/artifacts/blob/oci-artifact-manifest/artifact-manifest.md
[notary-v2-project]:            https://github.com/notaryproject/notaryproject