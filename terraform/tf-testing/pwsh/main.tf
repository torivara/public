terraform {
  required_version = "~> 1.2"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3"
    }
  }
}

resource "null_resource" "write_file" {
  triggers = {
    build_number = timestamp()
  }
  provisioner "local-exec" {
    command     = "'This is written by Terraform' | Out-File output.txt"
    interpreter = ["pwsh", "-NoProfile", "-Command"]
  }
}

resource "null_resource" "processes" {
  triggers = {
    build_number = timestamp()
  }
  provisioner "local-exec" {
    command     = "Get-Process | Select-Object -First 1"
    interpreter = ["pwsh", "-NoProfile", "-Command"]
  }
}
