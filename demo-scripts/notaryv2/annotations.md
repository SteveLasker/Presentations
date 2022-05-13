### Adding Context to the Signature

- Add Annotations, signifying what the signature represents

```bash
cat <<EOF > ./annotations.json
{
  "\$manifest": {
    "io.acme-rockets.policy.scanned": "policy12",
    "io.acme-rockets.policy.base-images": "approved",
    "io.cncf.oras.artifact.created": "2022-04-02T08:53:09.42"
  }
}
EOF

cat ./annotations.json | jq

oras push $REGISTRY/$REPO \
    --artifact-type 'application/vnd.oras.artifact.annotations' \
    --subject $ARTIFACT \
    --manifest-annotations annotations.json

oras discover -o tree $ARTIFACT
```

- Sign the annotations

  ```bash
  # Get the digest reference to the annotations artifact
  DIGEST=$(oras discover -o json \
                      --artifact-type application/vnd.oras.artifact.annotations \
                      $ARTIFACT | jq -r ".references[0].digest")

  notation sign --key $KEY_NAME $REGISTRY/$REPO@$DIGEST
  ```

- View the graph

    ```bash
    oras discover -o tree $ARTIFACT 
    ```