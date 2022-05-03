# Verifying Microsoft Registry Artifacts

## Acquire Notation Clients

Download the notation client with plugin support.  
  ❗ When [COSE support is merged into the notation client](https://github.com/notaryproject/notation/issues/163), users will simply use `notation verify` without a plug-in

1. Download the `notation` client, with plug-in support. see [notation feat-kv-extensibility release](https://github.com/notaryproject/notation/releases/tag/feat-kv-extensibility)

    ```bash
    # Choose a binary
    timestamp=20220121081115
    commit=17c7607

    # Download, extract and install
    curl -Lo notation.tar.gz https://github.com/notaryproject/notation/releases/download/feat-kv-extensibility/notation-feat-kv-extensibility-$timestamp-$commit.tar.gz

    tar xvzf notation.tar.gz

    tar xvzf notation_0.0.0-SNAPSHOT-${commit}_linux_amd64.tar.gz -C ~/bin notation
    ```

2. Download the `notation-cose` plugin for cose support. See [notation-cose v0.3.0-alpha.1](https://github.com/microsoft/notation-cose/releases/tag/v0.3.0-alpha.1)

    ```bash
    curl -L https://github.com/microsoft/notation-cose/releases/download/v0.3.0-alpha.1/notation-cose_0.3.0-alpha.1_Linux_amd64.tar.gz \
    | tar xzC ~/.config/notation/plugins/cose notation-cose
    ```

3. Configure notation to use the `notation-go` plug-in

    ```bash
    notation plugin add cose ~/.config/notation/plugins/cose/notation-cose
    ```

## Configure Microsoft Artifact Validation

1. Download the Microsoft Secure Supply Chain Public Key
    ```bash
    curl https://www.microsoft.com/pkiops/certs/Microsoft%20Supply%20Chain%20RSA%20Root%20CA%202022.crt --output msft_supply_chain.crt
    ```

1. Convert the public .cert to a .pem (see issue: [add support for binary-encoded x509 certs #157](https://github.com/notaryproject/notation/issues/157))

    ```bash
    openssl x509 -in msft_supply_chain.crt \
      -inform DER \
      -out msft_supply_chain.pem
    ```

1. Configure Notary verification

    ```console
      notation cert add --name msft_supply_chain \
        --plugin cose \
        --id msft_supply_chain.pem \
        --kms
    ```

1. Verify a public test image

    ```bash
     notation verify --cert msft_supply_chain \
       mcr.microsoft.com/mcr/hello-world-oras-canary:demo
    ```
