# Exp R, step 2 — the resource is gone from config; only a removed block remains,
# with NO lifecycle. OpenTofu defaults to FORGET (keep real object) and warns.
# Terraform (not run here) defaults to DESTROY in the same situation.
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

removed {
  from = local_file.demo
}
