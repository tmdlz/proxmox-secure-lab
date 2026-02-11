# Changelog

Toutes les modifications notables de ce projet sont documentées dans ce fichier.

Format basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/),
versioning basé sur [Semantic Versioning](https://semver.org/lang/fr/).

---

## [Unreleased]

### Added
- Structure initiale du projet
- README.md avec architecture et stack technique
- DECISIONS.md avec 6 ADR (IA, Forgejo, VictoriaMetrics, Woodpecker, ext4, LXC)
- Cahier des charges complet (CDC v3)
- .gitignore configuré pour le projet
- Licence MIT

---

## Roadmap

| Version | Phase | Description |
|---------|-------|-------------|
| v0.0-init | Setup | Structure du projet, CDC, documentation initiale |
| v0.1-network | Phase 0+1 | Installation Proxmox/NAS + réseau pfSense |
| v0.2-services | Phase 2 | Nginx, PostgreSQL, Monitoring |
| v0.3-cicd | Phase 3 | Forgejo, Woodpecker CI, Registry |
| v0.4-security | Phase 4 | Hardening complet |
| v0.5-automation | Phase 5 | Ansible, scripts, Terraform |
| v1.0-complete | Phase 6 | Backup, DR, projet complet |
