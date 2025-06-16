#!/usr/bin/env bash
ACTION=$1
CERTIFICATE_NAME=$2
KEY_VAULT_NAME=$3
# This script is used to manage the lifecycle of certificates in Azure Key Vault.

# verify input parameters
if [ -z "$ACTION" ] || [ -z "$CERTIFICATE_NAME" ] || [ -z "$KEY_VAULT_NAME" ]; then
    echo "Usage: $0 <action> <certificate_name> <key_vault_name>"
    echo "Actions: output, merge, output_to_console, delete_pending"
    exit 1
fi

########################################################################
# Initialize script
########################################################################

set -e
if [ "$ARM_CLIENT_SECRET" ]; then
    # We have crendentials in environment variables, use them to log in with az:
    az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" --output none
fi # else we assume running locally, and already signed in

########################################################################
# Output csr to json for terraform external data source
########################################################################

if [ "$ACTION" == "output" ]; then
    # Output csr to json for terraform external data source

    CSR=$(az keyvault certificate pending show --name "${CERTIFICATE_NAME}" --vault-name "${KEY_VAULT_NAME}" | jq -r '.csr')
    jq -n --arg csr "$CSR" '{"csr": $csr}'
fi

########################################################################
# If action merge, merge pending certificates in key vault
########################################################################

if [ "$ACTION" == "merge" ]; then
    # verify environment variables
    if [ -z "$SIGNED_CERTIFICATE" ]; then
        echo "Error: SIGNED_CERTIFICATE environment variable is not set."
        exit 1
    fi

    cat << EOF > "${CERTIFICATE_NAME}.csr"
$SIGNED_CERTIFICATE
EOF

    # Merge the signed certificate with the CSR in Azure Key Vault:
    az keyvault certificate pending merge --file "${CERTIFICATE_NAME}.csr" --name "${CERTIFICATE_NAME}" --vault-name "${KEY_VAULT_NAME}"
fi

########################################################################
# If action delete, delete pending certificates in key vault
########################################################################

if [ "$ACTION" == "delete_pending" ]; then
    az keyvault certificate pending delete --name "${CERTIFICATE_NAME}" --vault-name "${KEY_VAULT_NAME}"
fi

########################################################################
# Output csr and expiration to console for debugging purposes
########################################################################

if [ "$ACTION" == "output_to_console" ]; then
    # Output csr to console

    CSR=$(az keyvault certificate pending show --name "${CERTIFICATE_NAME}" --vault-name "${KEY_VAULT_NAME}" | jq -r '.csr')

    if [[ -z "$CSR" ]]; then
        CSR=$(az keyvault secret show --name "${CERTIFICATE_NAME}-csr" --vault-name "${KEY_VAULT_NAME}" | jq -r '.value')
    fi

    echo "-----BEGIN CERTIFICATE REQUEST-----"
    echo "$CSR"
    echo "-----END CERTIFICATE REQUEST-----"

    CERTIFICATE=$(az keyvault certificate show --name "${CERTIFICATE_NAME}" --vault-name "${KEY_VAULT_NAME}")

    if [ "$CERTIFICATE" ]; then
        EXPIRES=$(echo "$CERTIFICATE" | jq -r '.attributes.expires')
        CREATED=$(echo "$CERTIFICATE" | jq -r '.attributes.created')
        echo "Certificate $CERTIFICATE_NAME created at: $CREATED"
        echo "Certificate $CERTIFICATE_NAME expires at: $EXPIRES"
    fi
fi
