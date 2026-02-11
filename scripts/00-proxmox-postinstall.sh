#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Proxmox Secure Lab — Script post-installation Proxmox VE
# ══════════════════════════════════════════════════════════════
#
# Usage : bash scripts/00-proxmox-postinstall.sh
# Prérequis : exécuter en root sur le nœud Proxmox fraîchement installé
#
# 🚧 Ce script sera complété lors de la Phase 0.
#    Structure prévue ci-dessous.
# ══════════════════════════════════════════════════════════════

set -euo pipefail

# ── Couleurs ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ── Vérifications ──
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté en root."
    exit 1
fi

if ! command -v pveversion &> /dev/null; then
    log_error "Proxmox VE non détecté. Ce script est destiné à un nœud Proxmox."
    exit 1
fi

log_info "Proxmox VE détecté : $(pveversion)"
log_info "Début de la configuration post-installation..."

# TODO: Phase 0
# 1. Désactiver le repo enterprise
# 2. Activer le repo no-subscription
# 3. Supprimer le popup de souscription
# 4. Mise à jour système
# 5. Configuration swap (4 Go) + swappiness
# 6. Installation paquets utiles
# 7. Hardening SSH de base
# 8. Configuration réseau bridge vmbr0 VLAN-aware
# 9. Résumé post-installation

log_info "🚧 Script en cours de développement — Phase 0"
