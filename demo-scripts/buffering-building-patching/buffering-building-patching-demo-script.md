# Leveraging Build Pipelines for Automating Container OS & Framework Patching

## Abstract

Containers have become the modern packaging format, regardless of the host they're run on. You may be building your own images, or consuming images from ISVs. While containers have a focused subset of their VM ancestors, containers still have layers of the OS, runtimes and other components that are susceptible to vulnerabilities that must be remediated. Have you considered how you'll patch these deployments? Will you patch the running containers, as you patch VMs, hoping the software continues to run, as you continually patch the same deployed image?

We'll examine leveraging your build and deployment pipelines to automatically patch, test and deploy updates, during and long after you've moved onto another project. OS & Framework Patching can be an extension of what you're already doing today.

## Story Arch

## Container Value

- Modern day packaging format
- Base images provide the base capabilities, while apps add their capabilities
- Configuration extracted, enabling the same image to be deployed across different environments (dev, test, prod), or even different customer sites (Contoso, Northwind, AdventureWorks)

## Problem Statement

- Where do you get your base images from?
- Do you, should you, blindly trust upstream content?
- How do you balance the use of upstream content, while assuring stability?
- Once the dev team moves onto other projects, how do you patch containers? *Paradigm shift from VM workloads*

## Opportunity

- Leveraging your DevOps build pipeline to patch deployments
- Leveraging your development phase test infrastructure for the life of the app

## Look at Dev Phase

- Build Pipeline that pulls FROM upstream
- Unit Tests, verifying builds
- Security Scanning, assuring secure content, before deploying to any environment
- Functional Tests that validate before larger deployment

Animation

- Insert a central base-artifact registry
  - Provides a buffer of availability as your no longer dependent on the availability of an external resource
- How do you keep central base-artifacts updated?
  - Timer or Event based triggers?
  - Pull/Push or a server side import? [acr import](https://aka.ms/acr/import)
- How do you know these upstream changes meet your needs?

## Visualization

### Artifact Registries

- Upstream Registries (Docker Hub, Quay, gcr, GitHub Package Registry)
- Company specific, base-artifact registry (demo42baseartifacts)
- Eng team specific repos, within a dev registry (demo42dev)
- Production registry, in a VNet, geo-replicated (demo42prod)
- Archive registry - for compliance, not updated, not-replicated, and no longer security scanned (demo42archive)
  - saves space, avoids noisy vulnerability alerts
- Move upstream to another ACR to demonstrate immediate notifications (demo42upstream)

### Security Scanning

Isolated from the build system

### Container Deployments

- AKS Dev
- AKS Staging & Prod

## Build System

## Local Developers (Inner Loop)

## Demo - Building with ACR Tasks

Lets look at how ACR Tasks can build images, initiated from your local machine (inner loop) to git and base image triggers that can sync upstream changes.

- remote build `az acr build ...`

- Task build, triggered from git-commits
- Change the FROM to a base-artifact registry
  - Show visualization - moving the FROM upstream to central base-artifacts registry
- Make a change to the base, demonstrating base image updates (background color)
- Show a test, that validates the base image - test the color of the background

Bubble up

Animation:

- Demonstrated git-triggered builds
- Demonstrated base image triggered builds
- Demonstrated unit tests
- Rinse, repeat for importing images to the base-image registry
- Create a staging repo for imported images
- Use base image updates for docker hub as well

## Staging Upstream Changes

- Visualize FROM statements changing
- Add Tasks to keep upstream in sync
- Show a break - color not valid (red=bad)

## Dev Team Moves Onto Project 2

What happens?

- Base-artifacts continue to be maintained
- New feature versions come in, that enable active teams to move forward
- New patched content comes in, securing existing deployed apps
- Automated testing continues, leveraging the tests created during active development
- If tests fail, teams can act
- If failures leak through, rollbacks are available, with the infra to add new tests
- Teams can focus on new work, only tending to anomalies, not continued debt of every app requires handholding

## Wrapping Up

- Building modern apps requires automation to keep up with the continued expectations
- There's no single app that serves all needs
- Invest in tests, as they're now valued for the life of the app
- Containers enable patching, and validation of the patching, before deployment
- Cloud Native developemnt involves automating cloud resources, that you never physically touch
- Automating these processes keep the wheels spinning

