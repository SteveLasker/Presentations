# Using ORAS

## Demo Setup

### Create Text Files

1. Create a working directory for `oras push`

    ```bash
    mkdir oras
    cd oras
    ```

1. Create some files

    ```bash
    echo "Layer 1" > layer1.txt
    echo "Layer 2" > layer2.txt
    ```

1. Create a download Directory for `oras pull`

    ```bash
    mkdir download
    ```

## Single File Push/Pull

1. **ORAS login**  
  Login to ORAS with username/passwords. In this case, we store the username/password in Azure Key Vault.

```bash
oras login demo42.azurecr.io \
  -u $(az keyvault secret show \
            --vault-name demo42 \
            --name demo42-push-pull-usr \
            --query value -o tsv) \
  -p $(az keyvault secret show \
            --vault-name demo42 \
            --name demo42-push-pull-pwd \
            --query value -o tsv)
```

1. **Push a Single File**

    ```bash
    oras push demo42.azurecr.io/samples/text:v1 \
        ./layer1.txt
    ```

1. **View Repositories**

    ```bash
    az acr repository show \
        --name demo42 \
        --image samples/text:v1 \
        -o jsonc
    ```

1. **Pull the Artifact**

    ```bash
    cd download
    oras pull demo42.azurecr.io/samples/text:v1 -a
    ls
    ```

## Multi File Push/Pull

1. **Push Multiple File**  
  Push 2 files, under a newer versioned tag:

    ```bash
    cd ../
    oras push demo42.azurecr.io/samples/text:v2 \
        ./layer1.txt \
        ./layer2.txt
    ```

1. **Pull the Artifact**  
  Pull the additional file, into the `download` directory

    ```bash
    cd download
    oras pull demo42.azurecr.io/samples/text:v2 -a
    ls
    ```

## Update a Single Layers Content

1. Change the content of `layer2.txt`

    ```bash
    echo "Layer 2-update" > layer2.txt
    cat layer2.txt
    ```

1. Push the Update

    ```bash
    oras push demo42.azurecr.io/samples/text:v2 \
        ./layer1.txt \
        ./layer2.txt
    ```

1. Pull the update

    ```bash
    cd download
    oras pull demo42.azurecr.io/samples/text:v2 -a
    ls
    ```
    1. View the OCI Manifest

    ```bash
    getOciManifest demo42.azurecr.io/samples/text:v2
    ```
