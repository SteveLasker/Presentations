# Adding Service Reference, and a Claim

## Demo Today

- Show the Artifact Reference
  ```bash
  echo $ARTIFACT
  ```
- Build the `net-monitor:v1` image

  ```bash
  # Build & Push a Container Image
  docker build -t $ARTIFACT https://github.com/wabbit-networks/net-monitor.git#main

  docker push $ARTIFACT
  ```
- View the contents of the registry

  ```bash
  oras discover -o tree $ARTIFACT
  ```
- Sign the image

    ```bash
    notation sign --key $KEY_NAME $ARTIFACT 
    ```

- View the graph

    ```bash
    oras discover -o tree $ARTIFACT 
    ```

- View in the Azure Portal  
  [ACR Portal w/Preview](https://aka.ms/acr/portal/preview)

### Add Claims

- Create a claim for the `net-monitor:v1` image

  ```bash
  cat <<EOF > ./claims.json
  {
    "mediaType": "application/vnd.ietf.scitt.claim.v0.1",
    "claim-created": "2022-04-20T08:53:09.42",
    "claim-identity": "<identifier>",
    "subject": [
      {
        "io.cncf.oras.artifact.artifact-name": "io.wabbit-networks.registry/net-monitor:v1",
        "mediaType": "application/vnd.oci.image.manifest.v1+json",
        "digest": "sha256:41d62a3...110aa58a",
        "size": 25851449
      }
    ],
    "gov.nist.csrc.ssdf.1.1": "true",
    "io.something.else.important": "possible",
    "exclusions": [
      {
        "package": "name"
      }
    ]
  }
  EOF
  ```

- View the claim

  ```bash
  cat ./claims.json | jq
  ```

- Push the claim

  ```bash
  oras push $REGISTRY/$REPO \
      --artifact-type 'application/vnd.ietf.scitt.v1' \
      --subject $ARTIFACT \
      --manifest-annotations annotations.json \
      ./claims.json:application/json
  ```
- Sign the claim

  ```bash
  DIGEST=$(oras discover -o json \
                    --artifact-type application/vnd.ietf.scitt.v1 \
                    $ARTIFACT | jq -r ".references[0].digest")

  notation sign --key $KEY_NAME $REGISTRY/$REPO@$DIGEST
  ```


- View the claim manifest

  ```bash
  oras discover -o tree $ARTIFACT
  ```

- Pull the claim

  ```bash
  oras pull -a -o ./download $REGISTRY/$REPO@$CLAIMS_DIGEST
  ```

### Claims for Services

  How to associate a claim with content, not in the registry

  How to add a claim to the Microsoft Office 365 Service

  Create an synthetic artifact that represents the service, for a particular time period

#### Service Reference

- Create a service name for identification
  ```bash
  SERVICE_NAME=microsoft/office/365
  SERVICE_VERSION=2022-Q1-M1
  SERVICE_URL=$REGISTRY/$SERVICE_NAME:$SERVICE_VERSION

  echo SERVICE_URL=$SERVICE_URL
  ```
- Create a Service Definition

  ```bash
  cat <<EOF > ./service.json
  {
    "vendor": "microsoft.com",
    "service": "com.microsoft.office.365:2022-Q1-M1",
    "documentation": "https://www.microsoft.com/microsoft-365/"
  }
  EOF
  ```

- View the Service Definition

  ```bash
  cat ./service.json | jq
  ```

- Push Service Definition to the Registry

  ```bash
  oras push $SERVICE_URL \
      --manifest-config /dev/null:application/vnd.cncf.oras.artifacts.services.v1 \
      ./service.json:application/json
  ```

- Sign the Service Definition
```bash
notation sign --key $KEY_NAME $SERVICE_URL
```
- View the Graph
```bash
oras discover -o tree $SERVICE_URL
```

- Create a claim for Office 365

  ```bash
  cat <<EOF > ./claims.json
  {
    "mediaType": "application/vnd.ietf.scitt.claim.v0.1",
    "claim-created": "2022-04-20T08:53:09.42",
    "claim-identity": "<identifier>",
    "subject": [
      {
        "reference": "microsoft/office365:2022-Q1-M1",
        "mediaType": "application/vnd.cncf.oras.artifact.manifest.v1+json",
        "digest": "sha256:e20c3d22ebcb52f5d283499d1458e036bd9c7d5deee19fb01d3566d76ec44d0c",
        "size": 25851449
      }
    ],
    "gov.nist.csrc.ssdf.1.1": "true",
    "io.something.else.important": "possible",
    "exclusions": [
      {
        "package": "name"
      }
    ]
  }
  EOF
  ```

- View the Claim
  ```bash
  cat ./claims.json | jq
  ```
- Push the claim

  ```bash
  oras push $REGISTRY/$SERVICE_NAME \
      --artifact-type 'application/vnd.ietf.scitt.v1' \
      --subject $SERVICE_URL \
      ./claims.json:application/json
  ```

- Sign the claim

  ```bash
  DIGEST=$(oras discover -o json \
                    --artifact-type application/vnd.ietf.scitt.v1 \
                    $SERVICE_URL | jq -r ".references[0].digest")

  notation sign --key $KEY_NAME $REGISTRY/$SERVICE_NAME@$DIGEST
  ```


- View the claim manifest

  ```bash
  oras discover -o tree $SERVICE_URL
  ```
