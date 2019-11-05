# Buffering Base Artifacts Demo Script

## Troubleshooting

- Be sure your deploying an image that exists. Copy/paste and pull locally to verify
- Assure creds are configured between AKS and ACR - See [ACR Diagnostics & Logging](https://aka.ms/acr/diagnostics)

## Image & Tags on MCR

- https://mcr.microsoft.com/v2/_catalog
- http://mcr.microsoft.com/v2/acr/azure-cli/tags/list
/v2/<name>/tags/list
- https://registry.hub.docker.com/v1/repositories/debian/tags

## Demo Setup

```sh
ACR_NAME=demo42t
```

- Import base-image/node:9-alpine

  ```sh
  az acr import -n ${ACR_NAME} --source docker.io/library/node:9-alpine -t base-artifacts/node:9-alpine

  az acr import -n ${ACR_NAME} --source docker.io/library/node:9-alpine -t base-artifacts/node:9-alpine
  ```

- Connect ACR and AKS

```sh
az aks update \
  -n ${AKS_NAME} \
  -g ${AKS_RG_NAME} \
  --attach-acr ${ACR_NAME}
```

- Login to AKS

  ```sh
  az aks get-credentials \
    --name ${AKS_NAME} \
    --resource-group ${AKS_RG_NAME}
  az aks browse \
      --name ${AKS_NAME} \
      --resource-group ${AKS_RG_NAME}
  ```

## Inner Loop

- Open `helloworld`
- Edit the `server.js`
- Using [ACR Tasks](https://aka.ms/acr/tasks), execute a **quick build**

  ```sh
  az acr build \
    --registry demo42t \
    -t demo42/helloworld:{{.Run.ID}} \
    .
  ```

- List images available, including the newly built image:

  ```sh
  az acr repository show-tags \
  --registry demo42t \
  --repository demo42/helloworld
  ```

- List tags in lastupdate, descending order
  - Or, browse the portal

  ```sh
  az acr repository show-tags \
    -n ${ACR_NAME} \
    --repository demo42/helloworld \
    --orderby time_desc \
    --detail \
    --query "[].{Tag:name,LastUpdate:lastUpdateTime}"
  ```

## Deploy to AKS

- Copy the tag from above
- Populate the value in `kube.yaml`
- Deploy to AKS

  ```sh
  kubectl apply -f kube.yaml
  ```

- Validate Deployment Occuring

  ```sh
  watch -n1 kubectl get pods
  ```

- Wait for the external IP address

  ```sh
  watch -n1 kubectl get service
  ```

- Browse the site, with the public IP from `get service`

## Automate Hello World Build

- Create an ACR Task

  ```sh
  az acr task create \
    --registry $ACR_NAME \
    -n helloworld \
    -f acr-task.yaml \
    --context $GIT_REPO \
    --git-access-token $(az keyvault secret show \
                  --vault-name $AKV_NAME \
                  --name $GIT_TOKEN_NAME \
                  --query value -o tsv)
  ```

- Manually run the task

    ```sh
    az acr task run --registry ${ACR_NAME} -n helloworld
    ```

- Update AKS Deployment
  - Update `kube.yaml` to reflect the new image id (tag)

  ```sh
  kubectl apply -f kube.yaml
  ```

- Automate Node Base Image

  ```sh
  az acr task create \
    --registry ${ACR_NAME} \
    -n base-image-node \
    -f acr-task.yaml \
    --context $BASE_IMAGE_NODE_REPO \
    --git-access-token $(az keyvault secret show \
                          --vault-name $AKV_NAME \
                          --name $GIT_TOKEN_NAME \
                          --query value -o tsv)
  ```

- Change The Backcolor
  - Open baseimage-node/Dockerfile
  - Change the color
  - Commit Changes

- Watch base image changes

  ```sh
  watch -n1 az acr task list-runs --registry demo42t
  ```

- Update Deployment
  - Update `kube.yaml`

  ```sh
  kubectl apply -f kube.yaml
  ```

  - Browse for updates

## Testing Images

- Test w/Curl
  grep the background color
  use orca to run curl, speeding execution

- Automate Deployment

  ```sh
  az acr task create \
    --registry ${ACR_NAME} \
    -n hello-world-deploy \
    -f acr-task-kube-deploy.yaml \
    --context $GIT_REPO \
    --git-access-token $(az keyvault secret show \
                          --vault-name $AKV_NAME \
                          --name $GIT_TOKEN_NAME \
                          --query value -o tsv)
  ```
