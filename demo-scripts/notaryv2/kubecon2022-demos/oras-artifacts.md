# ORAS Artifacts Demo Script

## Environmental Setup & Downloads

- See [demo-env-setup](demo-env-setup.md#variables) for environmental variables 
- See [demo-script-setup.md](./demo-script-setup.md) for each demo run

## Demo Script
- Instance distribution, w/ORAS Artifacts support
  ```bash
  docker run -d -p 5000:5000 ghcr.io/oras-project/registry:v0.0.3-alpha
  ```

- Create a named stub

  ```bash
  cat <<EOF > ./myservice.json
  {
    "name": "io.wabbit-networks.netmonitor:2022-Q1-M1",
    "documentation": "https://www.wabbit-networks.io/net-monitor/"
  }
  EOF
  ```
- Push a named reference to the registry

  ```bash
  oras push localhost:5000/services/net-monitor:2022-Q1-M1 \
      --manifest-config /dev/null:application/json \
      ./myservice.json:application/json
  ```

- Create an SBOM for the Service
  ```bash
  cat <<EOF > ./sbom.json
  {
    "version": "1.0.0.0",
    "id": "wabbit-networks/service/net-monitor:2202-abc123",
    "contents": [
      {"name": "value" },
      {"name": "value"}
    ]
  }  
  EOF
  ```

- Push the SBOM, for the service

  ```bash
  oras push localhost:5000/services/net-monitor \
    --artifact-type 'sbom/example' \
    --subject localhost:5000/services/net-monitor:2022-Q1-M1 \
    ./sbom.json:application/json
  ```

- Discover the graph

    ```console
    oras discover -o tree  localhost:5000/services/net-monitor:2022-Q1-M1
    ```

- Create a claim 

  ```bash
  cat <<EOF > ./claims.json
  {
    "claim-created": "2022-04-20T08:53:09.42",
    "claim-identity": "<identifier>",
    "subject": "wabbit-networks/service/net-monitor:build-abc123",
    "claims": [
      {
        "gov.nist.csrc.ssdf.1.1": "true"
      }
    ]
  }
  EOF
  ```

- Push the claim

  ```bash
  oras push localhost:5000/services/net-monitor \
      --artifact-type 'claims/example' \
      --subject localhost:5000/services/net-monitor:2022-Q1-M1 \
      ./claims.json:application/json
    ```
  -

- Push just some annotations
  ```bash
  cat <<EOF > ./annotations.json
  {
    "\$manifest": {
      "io.acme-rockets.policy.scanned": "policy12",
      "io.cncf.oras.artifact.eol": "2022-05-31",
      "io.cncf.oras.artifact.replaced-with": "2022-Q1-M3.1",
      "io.cncf.oras.artifact.created": "2022-04-02T08:53:09.42"
    }
  }
  EOF
  ```

- View the annotations

  ```bash
  cat ./annotations.json | jq
  ```

- Push the annotations

  ```bash
  oras push localhost:5000/services/net-monitor \
      --artifact-type 'application/vnd.oras.artifact.annotations' \
      --subject localhost:5000/services/net-monitor:2022-Q1-M1 \
      --manifest-annotations annotations.json
  ```

- Discover the graph

    ```console
    oras discover -o tree \
      localhost:5000/services/net-monitor:2022-Q1-M1
    ```

- Pull claims

    ```bash
    # Get the digest reference to the annotations artifact
    DIGEST=$(oras discover -o json \
                        --artifact-type claims/example \
                        localhost:5000/services/net-monitor:2022-Q1-M1 | jq -r ".references[0].digest")
    ```

- Download the claims

    ```bash
    oras pull -o ./download  \
        localhost:5000/services/net-monitor@$DIGEST
    ```

- View the claims

    ```bash
    cat ./download/claims.json | jq 
    ```

- Copy the graph

    ```console
    oras copy -r localhost:5000/services/net-monitor:2022-Q1-M1 \
        localhost:5000/wabbit-networks/net-monitor:2022-Q1-M1
    ```

- Discover the graph

    ```console
    oras discover -o tree \
        localhost:5000/wabbit-networks/net-monitor:2022-Q1-M1
    ```


    ```bash
    oras copy -r localhost:5000/services/net-monitor:2022-Q1-M1 \
        acmerockets.azurecr.io/wabbit-networks/net-monitor:2022-Q1-M1
    ```

    ```bash
    oras discover -o tree \
        acmerockets.azurecr.io/wabbit-networks/net-monitor:2022-Q1-M1
    ```

