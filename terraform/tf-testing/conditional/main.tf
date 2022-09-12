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
  default     = null
}

output "output" {
  value = var.input != null ? "You entered: ${var.input} into the variable" : "You didn't supply a value for the variable."
}
