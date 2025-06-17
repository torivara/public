locals {
  certificates = {
    demo-kverulant-no = {
      subject = "CN=demo.contoso.com"
      alternative_dns_names = [
        "demo.contoso.com",
        "contoso.com"
      ]
    }
  }

  script_path = "${path.module}/scripts"

  pending_csr = { for k, v in data.external.get_csr : k => v.result.csr }
  stored_csr  = { for k, v in azurerm_key_vault_secret.csr_storage : k => v.value }
  csr_lookup  = merge(local.stored_csr, local.pending_csr)
}

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
