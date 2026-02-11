#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# Proxmox Secure Lab — Initialisation du dépôt Git
# ══════════════════════════════════════════════════════════════
#
# Usage : bash init-repo.sh
#
# Ce script initialise le dépôt Git, effectue le premier commit
# et affiche les instructions pour lier à GitHub.
# ══════════════════════════════════════════════════════════════

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}  Proxmox Secure Lab — Init Git Repo${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo ""

# Init
git init
git branch -M main

# Chiffrer le vault avant le premier commit
echo -e "${YELLOW}[INFO]${NC} Pensez à chiffrer le vault avant de push :"
echo -e "       cd ansible/ && ansible-vault encrypt inventory/group_vars/vault.yml"
echo ""

# Premier commit
git add .
git commit -m "🎉 init: project structure for Proxmox Secure Lab v3

- README.md with architecture overview and tech stack
- DECISIONS.md with 6 ADRs (AI tools, Forgejo, VictoriaMetrics, Woodpecker, ext4, LXC)
- Ansible structure: inventory, playbooks, 7 roles, vault
- Script placeholders: post-install, NAS setup, backups, health check
- Docker Compose templates for all services
- Terraform placeholder (optional IaC)
- Documentation placeholders for all 7 phases
- .woodpecker.yml CI/CD pipeline reference
- .gitignore, LICENSE (MIT), CHANGELOG.md"

# Tag
git tag -a v0.0-init -m "v0.0-init: Project structure, CDC, documentation initiale"

echo ""
echo -e "${GREEN}✅ Dépôt initialisé avec succès !${NC}"
echo ""
echo -e "${YELLOW}Prochaines étapes :${NC}"
echo -e "  1. Créer le repo sur GitHub : ${CYAN}https://github.com/new${NC}"
echo -e "  2. Lier le remote :"
echo -e "     ${CYAN}git remote add origin git@github.com:TON-USERNAME/proxmox-secure-lab.git${NC}"
echo -e "  3. Push :"
echo -e "     ${CYAN}git push -u origin main${NC}"
echo -e "     ${CYAN}git push origin v0.0-init${NC}"
echo ""
echo -e "${GREEN}🚀 Bon courage pour la Phase 0 !${NC}"
