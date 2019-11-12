# Buffering Base Images - Decoupling Dependencies On External Resources

Buffering base images refers to decoupling your companies dependencies on externally managed images. For instance, images that source from public registries like: [docker hub](https://hub.docker.com), [gcr](https://cloud.google.com/container-registry/), [quay](https://quay.io), [github package registry](https://github.com/features/package-registry) or even other public [Azure Container Registries](https://aka.ms/acr).

Consider balancing these two, possibly conflicting goals:

- Do you really want an unexpected upstream change to possibly take out your production system?
- Do you want upstream security fixes, for the versions you depend upon, to be automatically deployed?

In this demo we'll use [acr tasks][acr-tasks] to orchestrate the following event driven flow:

- use [acr tasks][acr-tasks] to monitor base image updates, triggering the workflow
- run some unit tests on the newly pushed *docker hub* image
- if the unit tests pass, [import][acr-import] the image to a central `base-artifact` repository
- once the base-artifact repo is updated, trigger rebuilds of the images that depend on this upstream change
- sit back, and watch magic happen - we hope

## Demo Setup

The following is required setup, prior to the actual demo

Registries & Repositories
- Create a clone of docker hub for public images.  
  This allows us simulate a base image update, which would normally be initiated on docker hub.
- Create a central registry, which will host the base artifacts.
- Create a development team registry, that will host one more more teams that build and manage images  
  > Note: [repository based RBAC *(preview)* is now available][acr-rbac], enabling multiple teams to share a single registry, with unique permission sets

For the purposes of this demo, we'll create the 3 in single registry

- demo42t.azurecr.io
    - **upstream/** - simulation of docker hub
    - **base-artifacts/** - central location for all artifacts
    - **dev-team-a/**
      - **helloworld**
    - **dev-team-b/**
      - **queueworker/**


### Fork & Clone Repos

```sh
git clone ${GIT_NODE_UPSTREAM}
git clone ${GIT_NODE_IMPORT}
git clone ${GIT_HELLOWORLD}
```

## Create a Personal Access Token

- See [ACR Build Docs](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-tutorial-build-task#create-a-github-personal-access-token) for specific permissions
- Copy the PAT
  Note, setting the PAT here, and not in the `env.sh` will store the PAT within Azure Key Vault for subsequent reference

  ```sh
  GITHUB_TOKEN=[Github PAT]
  ```

### Setup Environment Variables for Copy/Paste

- Edit [./env.sh](./env.sh) to match your environment variables
- Import [./env.sh](./env.sh) to your shell

  ```sh
  source ./env.sh
  ```

### Create Key Vault Entries

- GitHub Token secret
  ```sh

  az keyvault create --resource-group $RESOURCE_GROUP --name $AKV_NAME

  az keyvault secret set \
  --vault-name $AKV_NAME \
  --name github-token \
  --value $GITHUB_TOKEN
  ```

- Verify the values were saved

    ```sh
    az keyvault secret show \
      --vault-name $AKV_NAME \
      --name $GIT_TOKEN_NAME \
      --query value -o tsv
    ```

### Create a Registry

- Create the registry
  ```sh
  az group create \
    --name $RESOURCE_GROUP \
    --location $REGION

  az acr create \
    --resource-group $RESOURCE_GROUP \
    --name ${ACR_NAME} \
    --sku Premium
  ```

- Configure AZ cli defaults

  ```sh
  az configure --defaults acr=${ACR_NAME}
  ```
### Create a Central Base Image ACR

Regardless of the size of the company, you'll likely want to have a separate registry for managing base images. While it's possible to share a registry with multiple development teams, it's difficult to know how each team may work, possibly requiring VNet features, or other registry specific capabilities. To avoid future registry migration, we'll assume a separate registry for these centrally managed base images.

For the purposes of a demo, we'll consolidate them into one with different repos

- Create Azure Container Registries  
  With environment variables set, create two registries. Note, the central registry is a Standard SKU as it doesn't require advanced configurations. The Dev registry will be put in a VNet, requiring the Premium SKU.
  > Note: A consumption based tier is coming, easing these choices.

```sh
#az group create --name $RESOURCE_GROUP --location $REGION
#az acr create --resource-group $RESOURCE_GROUP --name $ACR_BASE_NAME --sku Standard
#az acr create --resource-group $RESOURCE_GROUP --name $REGISTRY_DEV --sku Premium
```

### Create a Simulated Public Image

Normally, this step wouldn't be needed as you would create a buffered image directly from the official node image. However, in this demo, we want to show what happens when the "official" node image is updated. 

While we could put the image on our personal `docker.io/[user]/node` repository, ACR Task base image notifications from Docker Hub aren't event driven. ACR Tasks tracks which images are needed from Docker Hub, and retrieves them with a random interval between 10 and 60 minutes. While this works well for large scaling, it makes it hard to see changes quickly. Tasks base image notifications from Azure Container Registries are event driven, making them near immediate, and easy to validate and demonstrate.

To simulate a public image, we'll simply push the node image to `[registry].azurecr.io/hub/node:9-alpine`. As with any cloud-naive experience, we'll automate this with an ACR Task.

#### Single Registry Scenario for Demonstrations

| Scenario | Registry|
|-|-|
| **docker hub** | `[registry]/hub/node`
| **central base images** | `[registry]/base-artifacts/node`
| **development teams** | `[registry]/dev-team-a/hellowrold`
| **development teams** | `[registry]/dev-team-b/queueworker`

#### Multiple Registry Sceanrio for Common Deployments

In this case, we leverage Docker Hub for the public base images, importing them into central team, under the contosocentral registry. This registry is geo-replicated across several regions, where the development teams operate.

The Development teams are split up between US and EU. In this case, the teams aren't split across the different continents, so there's no need to geo-replicate these registries. There's a contosodev**us** and contosodev**eu** registry. 

Production is secured through a VNet, with two different production environments. Each has their own VNet. To have the most isolation, each VNet has it's own registry. 

[ACR Import][acr-import] is used to move images between registries, including registries within a VNet.

| Scenario | Registry|
|-|-|
| **docker hub** | `docker.io/library/node`
| **central base images** | `constosocentral.azurecr.io/base-artifacts/node`
| **US based development teams** | `contosodevus.azurecr.io/dev-team-a/hellowrold`
| **US based development teams** | `contosodevus.azurecr.io/dev-team-b/queueworker`
| **EU based development teams** | `contosodeveu.azurecr.io/dev-team-b/emailer`
| **production a** | `contosoprod.azurecr.io/marketing-campaign/web`
| **production a** | `contosoprod.azurecr.io/marketing-campaign/emailer`
| **production b** | `contosoprod.azurecr.io/warranty-claims/web`
| **production b** | `contosoprod.azurecr.io/warranty-claims/queueworker`

## Hub Mirrored Images

To simulate images on Docker Hub, which we can make direct changes to, we'll create a task to automatically build these images.


- Push/Pull the Node image to this repository

  ```sh
  az acr task create \
    --name node-hub \
    -f acr-task.yaml \
    --context ${GIT_NODE_UPSTREAM} \
    --git-access-token $(az keyvault secret show \
                          --vault-name $AKV_NAME \
                          --name github-token \
                          --query value -o tsv)
  ```

- Start the task

  ```sh
  az acr task run --name node-hub
  ```

### Create an AKS Cluster
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
  ```

- Installing KubeCTL Client

  ```sh
  sudo az aks install-cli
  ```

- Browse the AKS portal

  ```sh
  az aks browse \
      --name ${AKS_NAME} \
      --resource-group ${AKS_RG_NAME}
  ```


### Install Helm

- Installing Helm Client

  ```sh
  curl -LO https://get.helm.sh/helm-v3.0.0-rc.3-linux-amd64.tar.gz
  tar -xzvf helm-v3.0.0-rc.3-linux-amd64.tar.gz
  sudo cp helm /usr/local/bin
  ```

## Demo Reset

- Reset `helloworld/Dockerfile` to

  ```dockerfile
  FROM node:9-alpine
  ```

- Reset `node-baseimage-import/Dockerfile` to disable the test validations

  ```dockerfile
  FROM demo42t.azurecr.io/hub/node:9-alpine
  WORKDIR /test
  COPY ./test.sh .
  #CMD ./test.sh
  ```

- Uninstall helloworld AKS deployment

  ```sh
  helm uninstall helloworld
  ```

- Open a Browser to the following URLs:
  - [Azure Portal](https://aka.ms/publicportal)
  - Deployed [helloworld](http://104.214.72.98/)
  - [GitHub helloworld](https://github.com/demo42/helloworld/blob/master/server.js)
  - [GitHub node upstream dockerfile](https://github.com/demo42/node-upstream/blob/master/Dockerfile)

- Open two Ubuntu Windows
  ```sh
  cd demo42/helloworld
  source ./env.sh
  ```

## Demo Steps

> The following are the steps for the actual demo.

## Inner Loop

Before creating a full fledged deployment flow, lets start with a single container

- Open `helloworld`
- Edit the `server.js`
- Using [ACR Tasks](https://aka.ms/acr/tasks), execute a **quick build**

  ```sh
  az acr build \
    -t ${ACR_NAME}.azurecr.io/demo42/helloworld:{{.Run.ID}} \
    .
  ```

- List images available, including the newly built image:

  ```sh
  az acr repository show-tags \
  --repository demo42/helloworld
  ```

- List tags in lastupdate, descending order
  - Or, browse the portal

  ```sh
  az acr repository show-tags \
    --repository demo42/helloworld \
    --orderby time_desc \
    --detail \
    --query "[].{Tag:name,LastUpdate:lastUpdateTime}"
  ```

## Deploy to AKS

Using [Helm 3][helm-3], we'll deploy the chart

- Get the last tag
  ```sh
  TAG=$(az acr repository show-tags \
        --repository demo42/helloworld \
        --orderby time_desc \
        --detail \
        --top 1 \
        --query "[].{Tag:name}" \
        -o tsv)
  ```

- Initial Install

  ```sh
  helm install helloworld ./charts/helloworld  \
    --set helloworld.image=${ACR_NAME}.azurecr.io/demo42/helloworld:${TAG}
  ```

- Validate Deployment Occurring

  ```sh
  watch -n1 kubectl get pods
  ```

- Wait for the external IP address

  ```sh
  watch -n1 kubectl get service
  ```

- Browse the site, with the public IP from `get service`

## Automate `helloworld` Build

To automate image building, we'll create a task, triggered by git commits

- Create an ACR Task

  ```sh
  az acr task create \
    -n helloworld \
    -t demo42/helloworld:{{.Run.ID}} \
    -f Dockerfile \
    --context $GIT_HELLOWORLD \
    --git-access-token $(az keyvault secret show \
                          --vault-name $AKV_NAME \
                          --name $GIT_TOKEN_NAME \
                          --query value -o tsv)
  ```

- Change `server.js`
- Commit the change
- Watch for changes

  ```sh
  watch -n1 az acr task list-runs
  ```

- Upgrade a new image
  When the build completes, deploy with `helm upgrade`

  ```sh
  TAG=$(az acr repository show-tags \
        --repository demo42/helloworld \
        --orderby time_desc \
        --top 1 \
        -o tsv)

  helm upgrade helloworld ./charts/helloworld/ \
    --reuse-values \
    --set helloworld.image=${ACR_NAME}.azurecr.io/demo42/helloworld:${TAG}
  ```

## Automate Build & Deploy

- Replace the build with a build & deploy task

  ```sh
  az acr task create \
    -n helloworld \
    -f acr-task.yaml \
    --context $GIT_HELLOWORLD \
    --assign-identity  \
    --git-access-token $(az keyvault secret show \
                          --vault-name $AKV_NAME \
                          --name $GIT_TOKEN_NAME \
                          --query value -o tsv)
  ```

- Assign the identity of the task, access to the registry and aks cluster
  
  ```sh
  az role assignment create \
    --role Contributor \
    --assignee-object-id $(az acr task show \
                            -n helloworld \
                            --query identity.principalId \
                            -o tsv) \
    --assignee-principal-type ServicePrincipal \
    --scope $(az acr show \
    -n ${ACR_NAME} \
    --query id -o tsv)
  ```

  ```sh
  az role assignment create \
  --role Contributor \
  --assignee-object-id $(az acr task show \
                          -n helloworld \
                          --query identity.principalId \
                          -o tsv) \
  --assignee-principal-type ServicePrincipal \
  --scope $(az aks show \
  -n ${AKS_NAME} \
  -g ${AKS_RG_NAME} \
  --query id -o tsv)
  ```

### Deploy a change to helloworld

- Change `server.js`
- Commit the change
- Watch for changes

  ```sh
  watch -n1 az acr task list-runs
  ```

- Or, just watch the latest log streaming output

  ```sh
  az acr task logs
  ```

- Browse the aks deployment

### Automate Public Image Importing to a Staging Repository

In [import-node-staging-task.yaml](./import-node-staging-task.yaml) we do a build, but only to get the base image, tag and digest for tracking. Once the build is done, we use [az acr import](https://aka.ms/acr/import) to copy the *public* image to our staging repo. 

We do require an identity for the task, as [az acr import](https://aka.ms/acr/import) must first `az login --identity` in order to run import.

- Create a task.yaml, for the graph execution  
  View [import-node-staging-task.yaml](./import-node-staging-task.yaml) in VS Code
- Create an ACR Tasks to monitor the *public (simulated)* base image
  
  ```sh
  az acr task create \
    --name node-import-base-image \
    --assign-identity  \
    -f acr-task.yaml \
    --context ${GIT_NODE_IMPORT} \
    --git-access-token $(az keyvault secret show \
                          --vault-name ${AKV_NAME} \
                          --name ${GIT_TOKEN_NAME} \
                          --query value -o tsv)
  ```

- Assign the identity of the task, access to the registry

  ```sh
  az role assignment create \
    --role Contributor \
    --assignee-object-id $(az acr task show \
        -n node-import-base-image \
        --query identity.principalId \
        -o tsv) \
    --assignee-principal-type ServicePrincipal \
    --scope $(az acr show \
      -n ${ACR_NAME} \
      --query id -o tsv)
  ```

  > Note: `--role contributor` See [Issue #281: acr import fails with acrpush role](https://github.com/Azure/acr/issues/281)  
  > Note: `az role assignment` See [Issue #283: az acr task create w/--use-identity to support role assignment](https://github.com/Azure/acr/issues/283) for incorporating the `az role assignment` into the task creation

- Manually run the task to start tracking the base image

  ```sh
  az acr task run -n node-import-base-image
  ```

### Test Base Image Notifications, w/Importing to Staging

- Monitor base image updates of our `import-node-to-staging` task

  ```sh
  watch -n1 az acr task list-runs
  ```

- Trigger a rebuild of the *public* base image  
  To ease context switching, change the [import-node-dockerfile](./import-node-dockerfile) directly in GitHub, committing directly to master. This will trigger a base image change, which should trigger the `import-node-to-staging` task

- Change the background color from white to Red

  ```sh
  FROM node:9-alpine
  ENV NODE_VERSION 9.1-alpine
  ENV BACKGROUND_COLOR Red
  ```

- Once committed, you should see the `simulated-public-node` updating, with a trigger of `Commit`

  ```sh
  RUN ID    TASK                    PLATFORM    STATUS     TRIGGER       STARTED               DURATION
  --------  ----------------------  ----------  ---------  ------------  --------------------  ----------
  cd89      helloworld              linux       Running    Image Update  2019-11-11T23:54:40Z
  cd88      node-import-base-image  linux       Succeeded  Image Update  2019-11-11T23:53:49Z  00:01:08
  cd87      node-hub                linux       Succeeded  Commit        2019-11-11T23:53:27Z  00:00:29
  ```

- Browse the AKS deployed helloworld app

### Checking In

At this point, we've successfully automated the importing of a base image to a registry under your control. If connectivity to the public registry is down, your development & production systems will continue to function.

If you need to implement a security fix, rather than changing all the dev projects to point at a newly patched image, you can simply patch your own base image. Once the change is moved upstream, you can resume upstream changes being automatically migrated through your system.

## Adding Validation Testing to `staging\node`

Now that we've successfully automated the importing of a base image to our staging repo, we should run some tests to validate this image performs as we expect. For instance, lets *block the red*

- Open `node-base-image-import/Dockerfile`
- Add the test script:

  ```dockerfile
  FROM demo42t.azurecr.io/hub/node:9-alpine
  WORKDIR /test
  COPY ./test.sh .
  CMD ./test.sh
  ```
- Open `test.sh` to see a basic unit test, blocking red. 

- Commit changes to run unit tests on the alpine image

- Monitor Task execution

  ```sh
  watch -n1 az acr task list-runs
  ```

- Node Import fails

- Stream the logs

  ```sh
  az acr task logs
  ```

- Change Background Color to trigger a base update

  ```sh
  FROM node:9-alpine
  ENV NODE_VERSION 9.1-alpine
  ENV BACKGROUND_COLOR DeepSkyBlue
  ```

- Commit and watch the changes

  ```sh
  watch -n1 az acr task list-runs
  ```


## Back to slides

## Troubleshooting

- Be sure your deploying an image that exists. Copy/paste and pull locally to verify
- Assure creds are configured between AKS and ACR - See [ACR Diagnostics & Logging](https://aka.ms/acr/diagnostics)
## Image & Tags on MCR

- https://mcr.microsoft.com/v2/_catalog
- https://mcr.microsoft.com/v2/acr/azure-cli/tags/list
- https://registry.hub.docker.com/v1/repositories/debian/tags

## Local Testing

```sh
az acr build -t node-import:test -f acr-task.yaml --no-push .
docker build -t node-import:test .
docker run -it --rm node-import:test

az acr import \
  --source demo42upstream.azurecr.io/library/node:9-alpine \
  -t base-artifacts/node:9-alpine \
  -t base-artifacts/node:9-alpine-$ID \
  --force
time az acr import \
  --source demo42upstream.azurecr.io/library/node:9-alpine \
  -t base-artifacts/node:9-alpine \
  -t base-artifacts/node:9-alpine-$ID \
  --force
time az acr import --source demo42upstream.azurecr.io/library/node:9-alpine -t base-artifacts/node:9-alpine --force
```

[acr-import]:   https://aka.ms/acr/import
[acr-tasks]:    https://aka.ms/acr/tasks
[acr-rbac]:     https://docs.microsoft.com/azure/container-registry/container-registry-repository-scoped-permissions
[helm-3]:       https://v3.helm.sh/docs/topics/registries/