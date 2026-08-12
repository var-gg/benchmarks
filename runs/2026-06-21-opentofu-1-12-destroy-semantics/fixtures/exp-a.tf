# Exp A — variable-driven prevent_destroy (NEW in 1.12).
# 1.11.x rejects a variable inside prevent_destroy at validate time;
# 1.12 accepts it as an evaluated expression.
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

variable "lock" {
  type    = bool
  default = true
}

resource "local_file" "note" {
  filename = "${path.module}/note.txt"
  content  = "exp-a"

  lifecycle {
    prevent_destroy = var.lock
  }
}
