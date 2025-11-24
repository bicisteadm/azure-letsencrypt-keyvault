# acme-kv

Tooling around `acme.sh` that issues and renews Let's Encrypt certificates for Azure workloads that do not support managed certificates. Fresh certificates are exported to PFX and uploaded to Azure Key Vault so that Container Apps, App Services, or other consumers can pull them on demand.

## Repository Layout
- `serving/` – a lightweight nginx container that exposes `/.well-known/acme-challenge/` for HTTP-01 validation.
- `renewer/` – the automation container that runs `acme.sh`, signs in with Managed Identity, and pushes certificates to Azure Key Vault.
- `docker-compose.yml` – local-only orchestrator that wires both containers together and shares the webroot, certificate cache, and logs.

## Production Deployment
Deployments run on Azure Container Apps with certificate storage in Azure Key Vault. The Terraform configuration that provisions the Container Apps environment, identities, and required secrets will be published soon—link to be added here once it is available.
