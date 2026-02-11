#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Proxmox Secure Lab — Script setup NAS / Backup (PC 2)
# ══════════════════════════════════════════════════════════════
#
# Usage : bash scripts/00-nas-setup.sh
# Prérequis : exécuter en root sur Debian 12 fraîchement installé
#
# 🚧 Ce script sera complété lors de la Phase 0.
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

log_info "Début de la configuration du NAS..."

# TODO: Phase 0
# 1. Mise à jour système
# 2. Installation paquets (nfs-kernel-server, rsync, gpg, smartmontools, fail2ban, ufw)
# 3. Création arborescence /backup/{vzdump/{daily,weekly},databases,configs}
# 4. Configuration exports NFS
# 5. Configuration UFW
# 6. Configuration SMART monitoring
# 7. Hardening SSH
# 8. Cron de nettoyage des vieux backups
# 9. Cron de surveillance espace disque
# 10. Test d'écriture NFS

log_info "🚧 Script en cours de développement — Phase 0"
