# Exp B — lifecycle { destroy = false } on a MANAGED resource (NEW in 1.12).
# destroy turns into "forget": state entry removed, real object kept.
# OpenTofu exits non-zero unless -suppress-forget-errors is passed.
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "local_file" "keep" {
  filename = "${path.module}/keep.txt"
  content  = "exp-b"

  lifecycle {
    destroy = false
  }
}
