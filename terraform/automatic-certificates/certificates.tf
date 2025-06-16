locals {
  certificates = {
    demo-kverulant-no = {
      subject = "CN=demo.kverulant.no"
      alternative_dns_names = [
        "demo.kverulant.no",
        "kverulant.no"
      ]
    }
  }

  script_path = "${path.module}/scripts"

  pending_csr = { for k, v in data.external.get_csr : k => v.result.csr }
  stored_csr  = { for k, v in azurerm_key_vault_secret.csr_storage : k => v.value }
  csr_lookup  = merge(local.stored_csr, local.pending_csr)
}

# Create certificates logic
# 1. Create Key Vault certificate for each certificate in the local.certificates map.
#    This will create a CSR in the Key Vault, also called a pending certificate.
# 2. Get the csr with bash in a local-exec provisioner.
#    The bash script will output the CSR in json format to be consumed as a property in the merge step.
# 3. Use acme_provider to sign the CSR and create a signed certificate.
# 4. Merge the signed certificate with the CSR using a local-exec provisioner.
#    When the signed certificate is merged, the certificate will be available in the key vault.
# 5. Use the key vault certificate in APIM.

# Renew certificates logic
# 1. Use a time_rotating resource to trigger the certificate rotation every 2 hours during development.
#    In production, this should be set to a longer interval, such as 14 days.
# 2. The null_resource.rotate_certificates_trigger will trigger the certificate rotation.
# 3. The azurerm_key_vault_certificate.certificates resource will be replaced when the trigger is activated.
# 4. The acme_certificate.certificates resource will be replaced when the trigger is activated.
# 5. The null_resource.merge_pending_certificates will be triggered to merge the signed certificate with the CSR.
# 6. The azurerm_key_vault_secret.csr_storage resource will be replaced when the trigger is activated.
# 7. The azurerm_key_vault_certificate.certificates resource will be replaced when the trigger is activated.
# 8. The Api Management service will use the updated Key Vault certificate when it automatically refreshes its certificates.

##############################################################
# Manual tools for managing certificates in terraform backend
# Uncomment these resources to use them, and add a suitable
# trigger to the null_resource to run them.
##############################################################

# Remove pending certificates in Key Vault
# Uncomment this resource if you need to remove all pending certificates.
# resource "null_resource" "remove_pending_csr" {
#   for_each = toset(["wildcard.kverulant.no"])
#   # trigger every time to delete all pending certificates
#   triggers = {
#     value = "manual run once"
#   }
#   provisioner "local-exec" {
#     command = "${local.script_path}/delete_pending.sh"
#     environment = {
#       CERTIFICATE_NAME = each.key
#       KEY_VAULT_NAME   = module.avm-res-keyvault-vault.name
#     }
#   }
# }

# Recover deleted certificate in Key Vault
# Uncomment this resource if you need to recover a deleted certificate.
# Make sure to replace <kv_certificate_name> with the actual name of the certificate you want to recover.
# resource "null_resource" "recover_deleted_certificate" {
#   triggers = {
#     value = "run only once"
#   }
#   provisioner "local-exec" {
#     command = <<SCRIPT
#     az login --service-principal -u "$ARM_CLIENT_ID" -p "$ARM_CLIENT_SECRET" --tenant "$ARM_TENANT_ID" --output none
#     az keyvault certificate recover --subscription ${data.azurerm_subscription.current.subscription_id} --vault-name ${module.avm-res-keyvault-vault.name} --name <certificate_name>
#     echo "Certificate xx has been recovered."
#     SCRIPT
#   }
# }
# Print the CSR to console for debugging purposes
# This resource outputs the CSR to the console for debugging purposes.
# This is useful during development to see the CSR that will be signed.
# resource "null_resource" "print_csr" {
#   for_each = { for k, v in data.external.get_csr : k => v }
#   # trigger every time during development
#   triggers = {
#     value = timestamp()
#   }
#   provisioner "local-exec" {
#     command = "${local.script_path}/output_csr_to_console.sh"
#     environment = {
#       CERTIFICATE_NAME = each.key
#       KEY_VAULT_NAME   = module.avm-res-keyvault-vault.name
#     }
#   }
#   depends_on = [
#     azurerm_key_vault_certificate.certificates
#   ]
# }

# Get the CSR from Key Vault and output it in valid json format
data "external" "get_csr" {
  for_each   = { for key, value in local.certificates : key => value }
  program    = ["bash", "${local.script_path}/certmgmt.sh", "output", each.key, module.avm-res-keyvault-vault.name]
  depends_on = [azurerm_key_vault_certificate.certificates]
}

# CSR is unfortunately not available after key vault certificate is merged
# Storing CSR in key vault as a workaround
# This resource will be replaced when automatic certificate renewal is run
resource "azurerm_key_vault_secret" "csr_storage" {
  for_each        = { for k, v in data.external.get_csr : k => v }
  key_vault_id    = module.avm-res-keyvault-vault.resource_id
  name            = "${each.key}-csr"
  content_type    = "text/plain"
  expiration_date = timeadd(timestamp(), "1128h") # 47 days
  value           = each.value.result.csr

  lifecycle {
    ignore_changes = [
      value,
      expiration_date
    ]
    # Forces replacement when the key vault is updated
    replace_triggered_by = [azurerm_key_vault_certificate.certificates[each.key]]
  }
}

# Register with ACME provider
# This resource registers the account with the ACME provider.
resource "acme_registration" "reg" {
  email_address = "your-email-address"
}

# Create the certificates using the ACME provider
# This resource uses the ACME provider to request a signed CSR from our internal CA
# This resource will be replaced when automatic certificate renewal is run
resource "acme_certificate" "certificates" {
  for_each                      = local.certificates
  account_key_pem               = acme_registration.reg.account_key_pem
  revoke_certificate_on_destroy = true
  certificate_request_pem       = <<EOT
-----BEGIN CERTIFICATE REQUEST-----
${local.csr_lookup[each.key]}
-----END CERTIFICATE REQUEST-----
EOT
  min_days_remaining            = 33

  dns_challenge {
    provider = "azuredns"
    config = {
      AZURE_PRIVATE_ZONE   = false
      AZURE_RESOURCE_GROUP = "dns-zones-rg"
      AZURE_ZONE_NAME      = local.dns_zone_name
      AZURE_AUTH_METHOD    = "env"
      AZURE_ENVIRONMENT    = "public"
    }
  }

  depends_on = [
    data.external.get_csr
  ]

  lifecycle {
    ignore_changes = [
      certificate_request_pem
    ]
    replace_triggered_by = [null_resource.rotate_certificates_trigger]
  }
}

# Complete the pending certificate merge in Key Vault
resource "null_resource" "merge_pending_certificates" {
  for_each = { for k, v in acme_certificate.certificates : k => v }
  # Trigger if any certificate value changes
  triggers = {
    certificate_pem = each.value.certificate_pem
    issuer_pem      = each.value.issuer_pem
  }
  provisioner "local-exec" {
    command = "${local.script_path}/certmgmt.sh \"merge\" \"${each.key}\" \"${module.avm-res-keyvault-vault.name}\""
    environment = {
      SIGNED_CERTIFICATE = <<CERTIFICATE
${each.value.certificate_pem}
${each.value.issuer_pem}
CERTIFICATE
    }
  }
  depends_on = [
    azurerm_key_vault_certificate.certificates,
    acme_certificate.certificates
  ]
}

# Output the signed certificate and issuer to console for debugging purposes
# This is useful during development to see the signed certificate and issuer that will be merged.
resource "null_resource" "output_signed_csr" {
  for_each = { for k, v in acme_certificate.certificates : k => v }
  # Trigger if any certificate value changes
  triggers = {
    certificate_pem = each.value.certificate_pem
    issuer_pem      = each.value.issuer_pem
  }
  provisioner "local-exec" {
    command = <<SCRIPT
    echo cert_pem - "${each.value.certificate_pem}"
    echo issuer_pem - "${each.value.issuer_pem}"
    SCRIPT
  }
  depends_on = [
    azurerm_key_vault_certificate.certificates,
  ]
}

# This resource is used to rotate the Key Vault certificate every 2 hours during development.
# In production, this should be set to a longer interval, such as 14 days.
resource "time_rotating" "cert_rotation" {
  rotation_hours = 1
}

resource "null_resource" "rotate_certificates_trigger" {
  triggers = {
    value = time_rotating.cert_rotation.id
    # Uncomment this to rotate certificates on each terraform run
    #value2 = timestamp()
  }
}

# Create the Key Vault certificates
# This resource creates the Key Vault certificates using the input from the local.certificates map.
resource "azurerm_key_vault_certificate" "certificates" {
  for_each     = local.certificates
  name         = each.key
  key_vault_id = module.avm-res-keyvault-vault.resource_id

  certificate_policy {
    issuer_parameters {
      # We sign the cerificate with LetsEncrypt or our own internal CA
      name = "Unknown"
    }

    key_properties {
      exportable = true
      key_size   = 4096
      key_type   = "RSA"
      reuse_key  = false
    }

    lifetime_action {
      action {
        action_type = "EmailContacts"
      }
      trigger {
        days_before_expiry = 14
      }
    }

    secret_properties {
      # This creates a pfx file in the Key Vault:
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      key_usage = [
        "digitalSignature"
      ]

      subject_alternative_names {
        dns_names = each.value["alternative_dns_names"]
      }

      subject            = each.value["subject"]
      validity_in_months = 1
    }
  }

  tags = local.tags
  lifecycle {
    replace_triggered_by = [null_resource.rotate_certificates_trigger]
  }
}
