terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~>0.12"
    }
    acme = {
      source  = "vancluever/acme"
      version = "~>2.32"
    }
    external = {
      source  = "hashicorp/external"
      version = "~>2.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "~>3.2"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "acme" {
  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
}
