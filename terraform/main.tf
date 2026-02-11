# ══════════════════════════════════════
# Proxmox Secure Lab — Terraform (optionnel)
# ══════════════════════════════════════
# Provider : bpg/proxmox
# 🚧 À compléter lors de la Phase 5.

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.50.0"
    }
  }
}
