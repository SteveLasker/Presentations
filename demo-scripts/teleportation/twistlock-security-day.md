# Twistlock Security Day Demo Script

## Baseline

- Change `server.js`
- Watch Automated Build

## Change the Base Image Reference

- Open `helloworld/dockerfile`
- Change the reference to:

  ```sh
  FROM demo42t.azurecr.io/base-artifacts/node:9-alpine
  ```

- Watch automated build/deploy

- Change the background color from white to Red

  ```sh
  FROM node:9-alpine
  ENV NODE_VERSION 9.1-alpine
  ENV BACKGROUND_COLOR Red
  ```

- Watch Automated Build

## Add Import Validation

- Open `node-base-image-import/Dockerfile`
- Add the test script:

  ```dockerfile
  FROM demo42t.azurecr.io/hub/node:9-alpine
  WORKDIR /test
  COPY ./test.sh .
  CMD ./test.sh
  ```
- Open `test.sh` to see a basic unit test, blocking red. 

- Add a validation step to `acr-tasks.yaml`

  ```yaml
    - id: validate-base-image
      # only continues if node-import:test returns a non-zero code
      when: ['build-base-image-test']
      cmd: {{.Run.Registry}}/node-import:test

## Validate e2e

- Change Background Color to trigger a base update

  ```sh
  FROM node:9-alpine
  ENV NODE_VERSION 9.1-alpine
  ENV BACKGROUND_COLOR DeepSkyBlue
  ```
