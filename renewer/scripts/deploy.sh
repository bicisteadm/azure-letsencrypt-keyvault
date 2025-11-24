#!/bin/sh

set -e

# =============================================================================
# Configuration
# =============================================================================
DOMAIN="$1"
KEYVAULT_NAME="${KEYVAULT_NAME}"
DOMAIN_DIR="/acme.sh/$DOMAIN"
CERT_PATH="$DOMAIN_DIR/cert.pem"
KEY_PATH="$DOMAIN_DIR/key.pem"
PFX_PATH="$DOMAIN_DIR/$DOMAIN.pfx"
PFX_PASS="${PFX_PASS}"

# Set log file for deploy script
LOG_DIR=${LOG_DIR:-"/logs"}
LOG_TO_FILE=${LOG_TO_FILE:-"false"}
LOG_FILE="${LOG_FILE:-"$LOG_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"}"

# Load shared logging functions
. /scripts/logging.sh

# =============================================================================
# Azure Authentication
# =============================================================================
log_info "Authenticating with Azure using managed identity..."
if ! az login --identity > /dev/null 2>&1; then
    log_error "Failed to authenticate with Azure managed identity"
    exit 1
fi
log_info "Successfully authenticated with Azure"

# =============================================================================
# Validation
# =============================================================================
# Check if domain is provided
if [ -z "$DOMAIN" ]; then
    log_error "Domain name is required as first argument"
    exit 1
fi

# Check if certificate files exist
if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
    log_error "Certificate files not found for domain: $DOMAIN"
    log_error "  Expected: $CERT_PATH and $KEY_PATH"
    exit 1
fi

# =============================================================================
# Certificate Processing
# =============================================================================
log_info "Creating PFX for domain: $DOMAIN..."

cat "$CERT_PATH" "$KEY_PATH" > "$DOMAIN_DIR/$DOMAIN.pem"
if ! run_cmd "OPENSSL" openssl pkcs12 -export -in "$DOMAIN_DIR/$DOMAIN.pem" -out "$PFX_PATH" -password pass:$PFX_PASS; then
    log_error "Failed to create PFX file for domain: $DOMAIN"
    exit 1
fi

log_info "PFX file created successfully: $PFX_PATH"

# =============================================================================
# Key Vault Upload
# =============================================================================
if [ -n "$KEYVAULT_NAME" ]; then
    # Replace dots with hyphens for certificate name (Azure KV naming requirements)
    CERT_NAME=$(echo "$DOMAIN" | tr '.' '-')
    
    log_info "Importing certificate into Azure Key Vault: $KEYVAULT_NAME..."
    if ! run_cmd "AZ" az keyvault certificate import \
      --vault-name "$KEYVAULT_NAME" \
      --name "$CERT_NAME" \
      --file "$PFX_PATH" \
      --password "$PFX_PASS"; then
        log_error "Failed to upload certificate to Key Vault"
        exit 1
    fi
    
    log_info "Certificate successfully uploaded to Key Vault as: $CERT_NAME"
    
    # Clean up temporary files after successful upload
    log_info "Cleaning up temporary files..."
    rm -f "$DOMAIN_DIR/$DOMAIN.pem"
    log_info "Temporary files cleaned up"
else
    log_warn "KEYVAULT_NAME not set, skipping Key Vault upload"
fi

log_info "Certificate processing completed successfully for domain: $DOMAIN"
