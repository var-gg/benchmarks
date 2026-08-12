# Exp R, step 1 — create local_file.demo so it exists in state.
# run.sh applies this, then swaps in exp-r-step2.tf (the removed block).
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "local_file" "demo" {
  filename = "${path.module}/demo.txt"
  content  = "exp-r"
}
