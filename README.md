# homeauto
Infrastructure deployment and configuration for home automation.

## Quick start

Build with: -

    build/build.sh -p <password>
    
Create and install root CA certificate in issuer-tls secret with: -

    out/deploy/deploy.sh --ca

Full re/deploy with: -

    out/deploy/deploy.sh --core

Application re/deploy with: -

    out/deploy/deploy.sh

Application re/deploy and delete state with: -

    out/deploy/deploy.sh --pv
