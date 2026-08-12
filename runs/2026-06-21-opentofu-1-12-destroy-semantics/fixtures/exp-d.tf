# Exp D — precedence: destroy = false vs prevent_destroy = true on ONE resource.
# destroy = false wins; the resource is forgotten and prevent_destroy does not block.
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "local_file" "both" {
  filename = "${path.module}/both.txt"
  content  = "exp-d"

  lifecycle {
    prevent_destroy = true
    destroy         = false
  }
}
