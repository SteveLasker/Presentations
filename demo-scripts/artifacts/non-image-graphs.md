
## Environment Variables

- Create Environment Variables

  ```bash
  ACR_NAME=wabbitnetworks
  REGISTRY=$ACR_NAME.azurecr.io
  REPO=services/microsoft/office
  TAG=2022-Q1-M1
  ```

- Create a named stub

  ```bash
  cat <<EOF > ./named-anchor.json
  {
    "name": "com.microsoft.office.365:2022-Q1-M1",
    "documentation": "https://www.microsoft.com/microsoft-365/"
  }
  EOF
  ```
- Push a named reference to the registry

  ```bash
  oras push $REGISTRY/$REPO:$TAG \
      --manifest-config /dev/null:application/json \
      ./named-anchor.json:application/json
  ```

- Create a claim 

  ```bash
  cat <<EOF > ./claims.json
  {
    "mediaType": "application/vnd.ietf.scitt.claim.v0.1",
    "claim-created": "2022-04-20T08:53:09.42",
    "claim-identity": "<identifier>",
    "subject": [
      {
        "reference": "$REGISTRY/$REPO:$TAG",
        "mediaType": "application/vnd.cncf.oras.artifact.manifest.v1+json",
        "digest": "sha256:41d62a3...110aa58a",
        "size": 25851449
      }
    ],
    "gov.nist.csrc.ssdf.1.1": "true"
  }
  EOF
  ```

- Push the claim

  ```bash
  oras push $REGISTRY/$REPO \
      --artifact-type 'application/vnd.ietf.scitt.v1' \
      --subject $REGISTRY/$REPO:$TAG \
      ./claims.json:application/json
  ```

- Sign the claim

- View the Office 365 Service/Claims

```bash
oras discover -o tree $REGISTRY/$REPO:$TAG
```