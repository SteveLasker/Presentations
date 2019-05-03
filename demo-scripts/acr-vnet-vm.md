# ACR VNet & Firewall Rules - VM

## Demo Setup

The following steps are pre-setup, before the demo to save time and focus on the unique aspects:

- Setup an ACR
    - Start with an existing Premium ACR
    - Have a hello-world image in the registry. We won't browse the image, so the actual image isn't important
- Create the VM
    ```sh
    az vm create \
        --resource-group dockervnetvm \
        --name dockerVmInVnet \
        --image UbuntuLTS \
        --admin-username azureuser \
        --generate-ssh-keys
    ```
- Make sure Cleanup Tool didn't disable port 22
- ssh into the machine
- Install docker
    ```sh
    sudo apt install docker.io -y
    ```
- [Install the az CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest)
- Configure az
    ```sh
    az configure
    ```
- Login to the az cli
    ```sh
    az login
    ```
- Set the registry default
    ```sh
    az configure --defaults acr=demo42
    ```
- Login to your registry
    ```sh
    sudo az acr login
    ```
- Exit SSH
    ```sh
    exit
    ```
## Demo Reset

- Login to Bash for the remote Linux VM
    - az login
    - az acr login
    - clear the image cache on the vm
        ```sh
        sudo docker rmi $(sudo docker images -a -q)
        clear
        ```
- Login to Powershell for the local machine
    - az login
    - az acr login
    - clear the image cache on the vm
        ```sh
        docker rmi $(docker images -a -q)
        clear
        ```
- Remove firewall rules
- Browse to: [Restrict access to an Azure container registry using an Azure virtual network or firewall rules](https://review.docs.microsoft.com/en-us/azure/container-registry/container-registry-vnet?branch=pr-en-us-58475)

## Demo Script
Hi I'm ___
In this video we'll demonstrate placing Azure Container Registry into a locked down VNet, white listing specific external resources to tunnel in.

- Click on Authentication Overview

Although ACR has multiple authentication options to secure registries to just the users and services you wish, we've heard clearly that some environments must be completely locked down, with no public ingress or egress.

As part of the lockdown, resources must be restricted to a virtual network within Azure. 

But, once locked down, how do you have selective resources, such as on-prem resources, or users working within the office to gain access?

Before VNet support, customers have to choose between running a registry themselves, possibly in their cluster, dealing with all the management of security, storage, reliability. They might even choose some OSS projects, or products. 

Choosing alternatives means you can't benefit from geo-replication, integrated auth, content-trust and other features coming like repo based permissions, auto-purge and perf enhancements of ACR.

We're happy to announce that **ACR now supports Virtual Networks and Firewall rules.**, so you don't have run your own registry.

Let's do a quick walkthrough to show how you can lock down ACR to a virtual network, and whitelist specific subnets access.

### Demo pull from the public endpoint
1. Show ACR in the [portal](https://aka.ms/acr/portal/vnet)
1. Click Repositories to show the list of images
1. From local: pull an image, using the public endpoint
    - login & pull from PowerShell
        ```sh
        az acr login -n demo42
        docker pull demo42.azurecr.io/hello-world
        ```
1. From a VM: pull an image, using the public endpoint
    - login & pull using ssh
        ```sh
        sudo az acr login -n demo42
        sudo docker pull demo42.azurecr.io/hello-world
        ```

### Put ACR in a VNet
1. Navigate to the VM in the portal
    1. Note Virutal network/subnet
1. Navigate to ACR in the portal
1. Enable VNet & Firewall Rules
    1. Click Firewalls and virtual networks
    1. Click **Selected networks**
    1. Add existing virtual network
        1. **Virtual Netwwork:** Add dockervnetrm-->myDockerVMVNET
        1. **Subnet:** Add myDockerVMVNET-->myDockerVMSubnet
        1. click **[Add]**
    1. click **[Save]**
    1. Click **Repositories**
        1. error: *Access denied...*
1. From local: pull an image, using the public endpoint
    - login & pull from PowerShell
        ```sh
        docker pull demo42.azurecr.io/hello-world

            Using default tag: latest
            Error response from daemon: denied
        ```
1. From a VM: pull an image, using the public endpoint
    - login & pull using ssh
        ```sh
        sudo docker pull demo42.azurecr.io/hello-world

            Using default tag: latest
            latest: Pulling from hello-world
            a073c86ecf9e: Pull complete
            ...
        ```
### Enable Portal Access

1. Click Repositories
    - Access denied - You do not have access
1. Click Firewalls and virtual networks
1. Add Firewall rule for your client/team
    - `131.107.0.0/16`

- Get the VNet name
    ```sh
    az network vnet list \
        --resource-group dockervnetvm \
        --query "[].{Name: name, Subnet: subnets[0].name}"    
    ```
### Local machine access

1. From local: pull an image, using the public endpoint
    - pull from PowerShell
        ```sh
        docker pull demo42.azurecr.io/hello-world

            Using default tag: latest
            latest: Pulling from hello-world
            a073c86ecf9e: Pull complete
            ...
        ```
