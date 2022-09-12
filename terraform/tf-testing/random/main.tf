terraform {
  required_version = "~> 1.2"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3"
    }
  }
}

variable "input" {
  type        = any
  description = "This is an input variable to your terraform code. Write whatever here."
  default     = "Hello world!"
}

resource "random_string" "randomly_generated_string" {
  length  = 15
  special = false
  numeric = true
  lower   = true
  upper   = false
}

resource "random_pet" "random_pet_name" {
}

output "output" {
  value = "The input variable contains: ${var.input}"
}

output "random_string" {
  value = "This is a randomly generated string: ${random_string.randomly_generated_string.result}"
}

output "random_pet_name" {
  value = "This is a randomly generated 'pet name' used for unique resource naming: ${random_pet.random_pet_name.id}"
}
