terraform {
  required_version = "~> 1.2"
}

variable "input" {
  type        = any
  description = "This is an input variable to your terraform code. Write whatever here."
  default     = "Hello world!"
}

output "output" {
  value = "The input variable contains: ${var.input}"
}
