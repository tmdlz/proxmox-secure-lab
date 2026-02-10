# 🔒 Proxmox Secure Test Lab — Prompt de construction (v3)

> **Objectif** : Transformer deux vieux laptops en environnement de test sécurisé avec Proxmox VE + NAS de backup, documenté et versionné sur GitHub pour un portfolio DevOps — stack modernisée 2025/2026.

---

## 📋 Contexte du projet

Je veux créer un **homelab sécurisé sur Proxmox VE** installé sur un vieux laptop (nœud principal), accompagné d'un **second laptop servant de NAS/backup**, destiné à servir d'environnement de test pour pratiquer l'administration système, le réseau et le DevOps. Le projet doit être **entièrement documenté**, **reproductible** via des scripts d'automatisation, et **publié sur GitHub** comme projet portfolio.

---

## 💻 Hardware disponible

### PC 1 — Nœud Proxmox principal

| Composant | Spec |
|-----------|------|
| **CPU** | Intel Core i5-8265U (4 cores / 8 threads, 8ème gen — Whiskey Lake) |
| **RAM** | 8 Go DDR4 |
| **Stockage** | 250 Go SSD |
| **VT-x/VT-d** | ✅ Supporté |
| **Rôle** | Hyperviseur Proxmox VE — héberge toutes les VMs et CTs |

### PC 2 — Serveur NAS / Backup

| Composant | Spec |
|-----------|------|
| **CPU** | Intel Core i5-5200U (2 cores / 4 threads, 5ème gen — Broadwell) |
| **RAM** | 8 Go DDR3L |
| **Stockage** | 1 To HDD |
| **Rôle** | Debian minimal — NFS/Samba + réception des backups vzdump + backup BDD |

---

## ⚠️ Contraintes 8 Go RAM — Stratégie d'optimisation

Avec seulement **8 Go sur le nœud Proxmox**, chaque Mo compte. Voici les règles :

### Principes

1. **Containers LXC en priorité** — Un CT consomme 10-50× moins qu'une VM (pas de kernel dédié)
2. **Seulement 2 VMs** — pfSense (obligatoire, pas de support LXC) + Kali (besoin d'un kernel complet)
3. **Swap configuré** — 4 Go de swap sur le SSD comme filet de sécurité
4. **Pas de surallocation agressive** — Garder ~512 Mo de marge pour Proxmox lui-même
5. **Services optionnels éteints** — Kali (VLAN 40) démarré uniquement quand nécessaire

### Budget RAM détaillé

| Composant | Type | RAM allouée | Notes |
|-----------|------|-------------|-------|
| **Proxmox VE** | Host | ~1 Go | OS seul, ext4 (pas de ZFS ARC) |
| **pfSense** | VM | 512 Mo | Firewall + DHCP + DNS — prévoir 768 Mo si IDS/IPS activé |
| **Nginx Reverse Proxy** | CT | 256 Mo | Léger en tant que proxy |
| **PostgreSQL** | CT | 512 Mo | Raisonnable pour du test |
| **VictoriaMetrics + Grafana** | CT | 512 Mo | VM remplace Prometheus — 30-50% moins gourmand en RAM |
| **Forgejo** | CT | 384 Mo | Git self-hosted communautaire (fork actif de Gitea) |
| **Woodpecker CI** | CT | 384 Mo | Fork actif de Drone CI, pipeline YAML compatible |
| **Docker Registry** | CT | 256 Mo | Registry v2 minimal |
| **Kali Linux** | VM | 2 Go | ⚡ **Éteint par défaut** — démarré à la demande |
| | | **~3,8 Go** | *(sans Kali)* |
| | | **~5,8 Go** | *(avec Kali — capacité max)* |
| **Marge libre** | — | ~2,2 Go | Buffers, cache, pics d'utilisation |

> 💡 **Gain vs v2** : ~600 Mo récupérés grâce à VictoriaMetrics (vs Prometheus) et Woodpecker (vs Drone). La marge passe de 1,6 Go à 2,2 Go.
>
> 💡 **Astuce** : Fusionner Forgejo + Woodpecker dans un seul CT est possible pour gagner ~256 Mo si besoin.

---

## 🎯 Cahier des charges fonctionnel

### Architecture cible

```
                        [INTERNET]
                            |
                    [PC 1 — Proxmox VE]
                            |
                [pfSense VM — Firewall/Router]
                    |               |
    ┌───────────────┼───────────────┼───────────────┐
    |               |               |               |
 VLAN 10         VLAN 20         VLAN 30         VLAN 40
 Management      Services        CI/CD           DMZ
 10.10.10.0/24   10.10.20.0/24   10.10.30.0/24   10.10.40.0/24
    |               |               |               |
 Proxmox UI      CT Nginx        CT Forgejo      VM Kali
 SSH             CT PostgreSQL   CT Woodpecker    (isolé)
                 CT Monitoring   CT Registry
                        |
                   [Réseau local]
                        |
                [PC 2 — Debian NAS]
                   NFS / Samba
                Backup vzdump
                Backup pg_dump
                1 To stockage
```

### Exigences techniques

- **Hyperviseur** : Proxmox VE 8.x (dernière version stable)
- **Filesystem** : ext4 (un seul SSD de 250 Go — ZFS inutile sans mirror)
- **Firewall** : pfSense CE en VM (512 Mo RAM)
- **Segmentation** : 4 VLANs avec règles firewall inter-VLAN
- **Accès distant** : Tailscale sur le nœud Proxmox (léger, pas de config NAT)
- **Automatisation** : Scripts Bash + Ansible pour le provisioning
- **Monitoring** : VictoriaMetrics + Grafana + Node Exporter (dans un seul CT)
- **CI/CD** : Forgejo + Woodpecker CI + Docker Registry privé
- **Backup** : vzdump local → rsync chiffré vers PC 2 (NAS)
- **Sécurité** : Fail2ban, SSH hardening, certificats auto-signés, UFW double couche
- **NAS** : Debian 12 minimal sur PC 2 avec NFS + script de réception backup

### Pourquoi cette stack plutôt qu'une autre ?

| Choix | Alternative écartée | Raison |
|-------|---------------------|--------|
| **Forgejo** | Gitea | Fork communautaire, gouvernance indépendante, développement plus actif depuis 2023. Gitea est passé sous contrôle d'une entité commerciale. |
| **Woodpecker CI** | Drone CI | Fork open source actif de Drone. Drone est quasi-abandonné depuis le rachat par Harness. Syntaxe YAML compatible. |
| **VictoriaMetrics** | Prometheus | Drop-in replacement, 30-50% moins gourmand en RAM/CPU, meilleure compression. PromQL compatible. |
| **ext4** | ZFS | Un seul disque SSD — ZFS n'apporte rien sans mirror et consomme de la RAM (ARC). |
| **pfSense VM** | OPNsense / VyOS | pfSense reste la référence la plus documentée pour un homelab. OPNsense serait aussi valable. |
| **LXC** | Docker everywhere | LXC est natif Proxmox, plus léger, meilleur contrôle réseau avec les VLANs. Docker tourne dans les CTs quand nécessaire (Woodpecker, Registry). |

---

## 🏗️ Plan de réalisation — Phase par phase

### Phase 0 : Préparation hardware & installation

#### PC 1 — Proxmox VE

```
Tâches :
1. Vérifier le BIOS du laptop i5-8265U :
   - Activer VT-x (Intel Virtualization Technology)
   - Activer VT-d (Intel VT for Directed I/O) si disponible
   - Désactiver Secure Boot
   - Configurer le boot USB en premier
2. Créer une clé USB bootable avec l'ISO Proxmox VE 8.x (Ventoy ou dd)
3. Installer Proxmox VE :
   - Filesystem : ext4 (un seul disque de 250 Go, ZFS inutile sans mirror)
   - Partitionnement : ~220 Go pour les VMs/CTs, ~20 Go pour l'OS, 4 Go swap
   - Hostname : pve-lab.local
   - IP statique : 10.10.10.1/24 (ou DHCP temporairement)
4. Configuration post-install :
   - Désactiver le repo entreprise :
     sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list
   - Activer le repo no-subscription :
     echo 'deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription' \
       > /etc/apt/sources.list.d/pve-no-subscription.list
   - Supprimer le popup de souscription (optionnel, QoL) :
     sed -Ei.bak "s/NotFound/Active/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
   - Mettre à jour : apt update && apt full-upgrade -y
   - Configurer le réseau bridge (vmbr0) pour les VLANs
   - Activer le VLAN-aware sur vmbr0
   - Ajouter 4 Go de swap :
     fallocate -l 4G /swapfile && chmod 600 /swapfile
     mkswap /swapfile && swapon /swapfile
     echo '/swapfile none swap sw 0 0' >> /etc/fstab
   - Réduire le swappiness (SSD) :
     echo 'vm.swappiness=10' >> /etc/sysctl.conf && sysctl -p
5. Sécuriser l'accès Proxmox :
   - Générer une paire de clés SSH sur ta machine perso
   - Copier la clé publique : ssh-copy-id root@IP_PROXMOX
   - Désactiver l'authentification par mot de passe SSH
   - Configurer Fail2ban pour SSH + Web UI Proxmox
   - (Optionnel) Changer le port Web UI 8006 → custom
```

#### PC 2 — Serveur NAS/Backup Debian

```
Tâches :
1. Installer Debian 12 minimal (netinstall) sur le laptop i5-5200U
   - Pas d'environnement de bureau (serveur headless)
   - Partitionnement : /boot 512 Mo, swap 4 Go, / le reste (~995 Go)
   - Hostname : nas-backup.local
   - IP statique : 10.10.10.2/24 (même réseau que Proxmox pour les backups)
2. Post-installation :
   - apt update && apt upgrade -y
   - Installer les essentiels :
     apt install -y nfs-kernel-server rsync gpg fail2ban ufw htop smartmontools
   - Configurer SMART monitoring (HDD de 1 To, surveiller la santé) :
     smartctl -a /dev/sda   # vérification initiale
     systemctl enable --now smartd
   - Créer la structure de stockage :
     mkdir -p /backup/{vzdump/{daily,weekly},databases,configs}
     chown -R nobody:nogroup /backup
   - Configurer NFS :
     cat >> /etc/exports << 'EOF'
     /backup/vzdump   10.10.10.0/24(rw,sync,no_subtree_check,no_root_squash)
     /backup/databases 10.10.10.0/24(rw,sync,no_subtree_check,no_root_squash)
     /backup/configs  10.10.10.0/24(rw,sync,no_subtree_check,no_root_squash)
     EOF
     exportfs -ra && systemctl enable --now nfs-kernel-server
   - Configurer UFW : autoriser SSH + NFS uniquement depuis 10.10.10.0/24
     ufw default deny incoming
     ufw default allow outgoing
     ufw allow from 10.10.10.0/24 to any port 22
     ufw allow from 10.10.10.0/24 to any port 2049
     ufw allow from 10.10.10.0/24 to any port 111
     ufw enable
   - SSH hardening identique au PC 1
3. Monter le NFS sur Proxmox :
   - Datacenter > Storage > Add > NFS
   - Server : 10.10.10.2, Export : /backup/vzdump
   - Content : VZDump backup file
4. Configurer un cron de surveillance disque sur PC 2 :
   - Script vérifiant l'espace libre (alerte si < 20%)
   - Rotation automatique des vieux backups
```

**Livrables GitHub** :
- `docs/00-hardware-setup.md`
- `scripts/00-proxmox-postinstall.sh`
- `scripts/00-nas-setup.sh`

---

### Phase 1 : Réseau & Segmentation (pfSense)

```
Tâches :
1. Configurer le bridge VLAN-aware sur Proxmox :
   - Éditer /etc/network/interfaces :
     auto vmbr0
     iface vmbr0 inet static
         address 10.10.10.1/24
         bridge-ports enpXs0    # adapter au nom réel de l'interface
         bridge-stp off
         bridge-fd 0
         bridge-vlan-aware yes
         bridge-vids 10 20 30 40

2. Créer la VM pfSense (optimisée pour 8 Go total) :
   - 1 vCPU, 512 Mo RAM, 8 Go disque virtio
   - NIC 1 : vmbr0 (WAN — accès internet, pas de VLAN tag)
   - NIC 2 : vmbr0 VLAN trunk (LAN — toutes les VLANs)
   - Installer pfSense CE depuis l'ISO
   - Assigner WAN (vtnet0) et LAN (vtnet1)

3. Configurer les VLANs dans pfSense :
   - VLAN 10 : Management    — 10.10.10.0/24 — GW: 10.10.10.254
   - VLAN 20 : Services      — 10.10.20.0/24 — GW: 10.10.20.254
   - VLAN 30 : CI/CD         — 10.10.30.0/24 — GW: 10.10.30.254
   - VLAN 40 : DMZ isolée    — 10.10.40.0/24 — GW: 10.10.40.254

4. Règles firewall inter-VLAN :
   - VLAN 10 (Management) → accès total à tous les VLANs (admin)
   - VLAN 20 ↔ VLAN 30 : ports spécifiques uniquement
     * TCP 80, 443 (HTTP/HTTPS)
     * TCP 22 (SSH)
     * TCP 3000 (Forgejo Web UI)
     * TCP 9090 (VictoriaMetrics)
     * TCP 3100 (Grafana)
     * TCP 8000 (Woodpecker Web UI)
   - VLAN 40 → BLOCK vers VLAN 10, 20, 30 (isolation totale)
   - VLAN 40 → ALLOW internet uniquement (pour updates Kali)
   - Tous les VLANs → ALLOW DNS vers pfSense (port 53)

5. Services pfSense :
   - DHCP par VLAN (plages .100 à .200)
   - DNS Resolver (Unbound) activé — résolution locale *.lab.local
   - NAT outbound automatique pour l'accès internet

6. Vérification :
   - Depuis un CT en VLAN 20, ping 10.10.30.X → OK (services autorisés)
   - Depuis VLAN 40, ping 10.10.20.X → TIMEOUT (bloqué)
   - Depuis tous les VLANs, ping 8.8.8.8 → OK (internet)
```

**Livrables GitHub** :
- `docs/01-network-architecture.md`
- `docs/diagrams/network-topology.png` (Excalidraw ou draw.io)
- `pfsense/firewall-rules-export.xml`

---

### Phase 2 : Services (VLAN 20)

```
Tâches :

1. Reverse Proxy Nginx — Container LXC Debian 12 (256 Mo RAM) :
   - Template : debian-12-standard
   - VLAN tag : 20, IP : 10.10.20.10/24
   - Installer Nginx :
     apt install nginx -y
   - Configurer comme reverse proxy pour les services internes :
     * grafana.lab.local   → 10.10.20.30:3000
     * forgejo.lab.local   → 10.10.30.10:3000
     * woodpecker.lab.local → 10.10.30.20:8000
     * registry.lab.local  → 10.10.30.30:5000
   - HTTPS avec certificats auto-signés :
     openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
       -keyout /etc/ssl/private/lab.key -out /etc/ssl/certs/lab.crt \
       -subj "/CN=*.lab.local"
   - Alternative : mini CA interne avec mkcert pour éviter les warnings navigateur

2. Base de données PostgreSQL — Container LXC Debian 12 (512 Mo RAM) :
   - VLAN tag : 20, IP : 10.10.20.20/24
   - Installer PostgreSQL 16 :
     sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" \
       > /etc/apt/sources.list.d/pgdg.list'
     wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor \
       > /etc/apt/trusted.gpg.d/pgdg.gpg
     apt update && apt install -y postgresql-16
   - Configuration sécurisée :
     * Créer un utilisateur applicatif (pas postgres) :
       CREATE USER appuser WITH PASSWORD 'CHANGE_ME';
       CREATE DATABASE appdb OWNER appuser;
     * pg_hba.conf : n'accepter que les connexions depuis les VLANs autorisés :
       host all appuser 10.10.20.0/24 scram-sha-256
       host all appuser 10.10.30.0/24 scram-sha-256
     * postgresql.conf :
       listen_addresses = '10.10.20.20'
       shared_buffers = 128MB        # ajusté pour 512 Mo RAM
       work_mem = 4MB
       effective_cache_size = 256MB
   - Script de backup quotidien :
     pg_dump -U postgres appdb | gzip > /backup/db_$(date +%Y%m%d).sql.gz
     Rotation : garder 7 jours, envoyer vers PC 2 via rsync

3. Monitoring — Container LXC Debian 12 (512 Mo RAM) :
   - VLAN tag : 20, IP : 10.10.20.30/24

   a) VictoriaMetrics (remplace Prometheus) :
     - Télécharger le binaire single-node depuis github.com/VictoriaMetrics/VictoriaMetrics/releases
     - Lancer avec paramètres optimisés pour homelab :
       ./victoria-metrics-prod \
         -storageDataPath=/var/lib/victoria-metrics \
         -retentionPeriod=30d \
         -memory.allowedPercent=40 \
         -httpListenAddr=:8428
     - Configurer le scrape via -promscrape.config=prometheus.yml :
       scrape_configs:
         - job_name: 'node'
           static_configs:
             - targets:
               - '10.10.10.1:9100'   # Proxmox host
               - '10.10.20.10:9100'  # Nginx
               - '10.10.20.20:9100'  # PostgreSQL
               - '10.10.30.10:9100'  # Forgejo
               - '10.10.30.20:9100'  # Woodpecker
               - '10.10.30.30:9100'  # Registry
         - job_name: 'postgres'
           static_configs:
             - targets: ['10.10.20.20:9187']
     - PromQL 100% compatible — les dashboards Grafana existants fonctionnent tels quels

   b) Grafana :
     - apt install -y grafana
     - Datasource : type Prometheus, URL http://localhost:8428
       (VictoriaMetrics expose une API compatible Prometheus)
     - Dashboards préconfigurés :
       → Node Exporter Full (ID: 1860)
       → PostgreSQL (ID: 9628)
       → VictoriaMetrics Single (ID: 10229)
     - Alertes :
       → Disque > 80% sur n'importe quel nœud
       → Service down (target unreachable > 2 min)
       → RAM > 85% sur le host Proxmox
       → Backup NAS manquant (custom metric via node_exporter textfile)
     - Notifications : webhook Discord/Telegram

   c) Node Exporter sur CHAQUE CT/VM :
     apt install -y prometheus-node-exporter
     # Active par défaut sur :9100
```

**Livrables GitHub** :
- `ansible/roles/webserver/` (Nginx reverse proxy)
- `ansible/roles/database/` (PostgreSQL)
- `ansible/roles/monitoring/` (VictoriaMetrics + Grafana)
- `docs/02-services-deployment.md`

---

### Phase 3 : Pipeline CI/CD (VLAN 30)

```
Tâches :

1. Forgejo — Container LXC Debian 12 (384 Mo RAM) :
   - VLAN tag : 30, IP : 10.10.30.10/24
   - Installation via binaire (plus léger que Docker dans un CT) :
     # Télécharger la dernière release depuis codeberg.org/forgejo/forgejo/releases
     wget https://codeberg.org/forgejo/forgejo/releases/download/vX.Y.Z/forgejo-X.Y.Z-linux-amd64
     chmod +x forgejo-* && mv forgejo-* /usr/local/bin/forgejo
   - Configurer avec SQLite (économie de RAM, pas besoin d'un PostgreSQL dédié)
   - Créer un user système et un service systemd :
     adduser --system --shell /bin/bash --group --home /home/forgejo forgejo
   - app.ini — config optimisée pour homelab :
     [server]
     ROOT_URL = https://forgejo.lab.local
     HTTP_PORT = 3000
     [database]
     DB_TYPE = sqlite3
     [cache]
     ADAPTER = memory
     [session]
     PROVIDER = memory
   - Configurer un miroir bidirectionnel avec GitHub :
     * New Migration → GitHub → URL du repo → Mirror
   - Configurer le webhook vers Woodpecker CI :
     * Settings → Webhooks → Add → URL: http://10.10.30.20:8000/hook

2. Woodpecker CI — Container LXC Debian 12 (384 Mo RAM) :
   - VLAN tag : 30, IP : 10.10.30.20/24
   - Prérequis : installer Docker CE dans le CT
     (Activer les features nesting + keyctl dans les options du CT Proxmox)
   - Installation Woodpecker Server + Agent :
     # Server
     docker run -d --name=woodpecker-server \
       -e WOODPECKER_HOST=http://10.10.30.20:8000 \
       -e WOODPECKER_OPEN=true \
       -e WOODPECKER_FORGEJO=true \
       -e WOODPECKER_FORGEJO_URL=http://10.10.30.10:3000 \
       -e WOODPECKER_FORGEJO_CLIENT=xxx \
       -e WOODPECKER_FORGEJO_SECRET=xxx \
       -e WOODPECKER_AGENT_SECRET=agent-shared-secret \
       -p 8000:8000 \
       woodpeckerci/woodpecker-server:latest

     # Agent (sur le même CT)
     docker run -d --name=woodpecker-agent \
       -e WOODPECKER_SERVER=10.10.30.20:9000 \
       -e WOODPECKER_AGENT_SECRET=agent-shared-secret \
       -e WOODPECKER_MAX_WORKFLOWS=2 \
       -v /var/run/docker.sock:/var/run/docker.sock \
       woodpeckerci/woodpecker-agent:latest

   - Pipeline de démo (.woodpecker.yml) :
     steps:
       - name: test
         image: alpine
         commands:
           - echo "Running tests..."

       - name: lint
         image: golangci/golangci-lint
         commands:
           - golangci-lint run

       - name: build
         image: docker
         commands:
           - docker build -t 10.10.30.30:5000/myapp:${CI_COMMIT_SHA:0:8} .
           - docker push 10.10.30.30:5000/myapp:${CI_COMMIT_SHA:0:8}
         volumes:
           - /var/run/docker.sock:/var/run/docker.sock

       - name: notify
         image: alpine/curl
         commands:
           - 'curl -X POST $DISCORD_WEBHOOK -H "Content-Type: application/json" -d "{\"content\": \"✅ Build OK: ${CI_REPO} @ ${CI_COMMIT_SHA:0:8}\"}"'
         when:
           - status: [success, failure]

3. Docker Registry — Container LXC Debian 12 (256 Mo RAM) :
   - VLAN tag : 30, IP : 10.10.30.30/24
   - Déployer Registry v2 :
     docker run -d -p 5000:5000 \
       -v /data/registry:/var/lib/registry \
       --name registry registry:2
   - Authentification basique :
     mkdir /auth
     docker run --rm --entrypoint htpasswd httpd:2 -Bbn admin CHANGE_ME > /auth/htpasswd
     # Relancer avec :
     docker run -d -p 5000:5000 \
       -v /data/registry:/var/lib/registry \
       -v /auth:/auth \
       -e REGISTRY_AUTH=htpasswd \
       -e REGISTRY_AUTH_HTPASSWD_REALM="Lab Registry" \
       -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
       --name registry registry:2
   - Garbage collection planifiée (cron hebdomadaire) :
     0 3 * * 0 docker exec registry bin/registry garbage-collect /etc/docker/registry/config.yml
   - Configurer tous les CTs Docker pour faire confiance au registry :
     /etc/docker/daemon.json → {"insecure-registries": ["10.10.30.30:5000"]}
```

**Livrables GitHub** :
- `ansible/roles/cicd/` (Forgejo + Woodpecker + Registry)
- `.woodpecker.yml` (pipeline de référence)
- `docker-compose/forgejo/docker-compose.yml`
- `docker-compose/woodpecker/docker-compose.yml`
- `docker-compose/registry/docker-compose.yml`
- `docs/03-cicd-pipeline.md`

---

### Phase 4 : Sécurité & Hardening

```
Tâches :

1. SSH Hardening (toutes les machines — PC 1, PC 2, tous les CTs/VMs) :
   - /etc/ssh/sshd_config :
     PermitRootLogin no              # (sauf Proxmox host si besoin)
     PasswordAuthentication no
     PubkeyAuthentication yes
     Port 2222                        # Port custom
     MaxAuthTries 3
     AllowUsers tom                   # Ton user uniquement
     ClientAliveInterval 300
     ClientAliveCountMax 2
     X11Forwarding no
     AllowTcpForwarding no           # sauf si tunnel nécessaire
   - Fail2ban :
     apt install fail2ban -y
     Jail SSH : maxretry=3, bantime=3600, findtime=600
     Jail Proxmox Web UI : surveiller /var/log/daemon.log
     Jail custom pour Forgejo :
       [forgejo]
       enabled = true
       filter = forgejo
       logpath = /home/forgejo/log/forgejo.log
       maxretry = 5
       bantime = 3600

2. Firewall local sur chaque machine :
   - UFW sur chaque CT/VM (en plus de pfSense) :
     ufw default deny incoming
     ufw default allow outgoing
     ufw allow from 10.10.10.0/24 to any port 2222  # SSH depuis management
     ufw allow [PORT_SERVICE]                         # Port du service spécifique
     ufw enable
   - Principe : double couche — pfSense (périmètre) + UFW (local)

3. Accès distant sécurisé :
   - Installer Tailscale sur le host Proxmox :
     curl -fsSL https://tailscale.com/install.sh | sh
     tailscale up --advertise-routes=10.10.10.0/24,10.10.20.0/24,10.10.30.0/24
   - Depuis ton PC perso/mobile : accès à Proxmox Web UI + SSH via Tailscale
   - NE PAS advertiser le VLAN 40 (DMZ) via Tailscale
   - MFA sur Proxmox Web UI :
     Datacenter > Permissions > Two Factor > TOTP
     Ajouter TOTP pour ton compte

4. Audit & Logs centralisés :
   - Option A — rsyslog (léger, recommandé pour 8 Go) :
     * Sur chaque CT/VM, configurer rsyslog :
       *.* @10.10.20.30:514
     * Sur le CT monitoring, recevoir avec rsyslog :
       module(load="imudp")
       input(type="imudp" port="514")
     * Logrotate :
       /var/log/*.log { daily, rotate 7, compress, missingok }

   - Option B — Promtail + Loki (si la RAM le permet) :
     * Plus riche (labels, recherche dans Grafana)
     * Mais consomme ~100-150 Mo de RAM en plus
     * À envisager seulement si le budget RAM le permet

5. Zone de test pentest (VLAN 40) :
   - VM Kali Linux — 2 Go RAM — ⚡ ÉTEINTE PAR DÉFAUT :
     qm create 200 --name kali-pentest --memory 2048 --cores 2 \
       --net0 virtio,bridge=vmbr0,tag=40 --cdrom local:iso/kali.iso \
       --ostype l26 --scsihw virtio-scsi-pci --boot order=scsi0
   - Démarrer uniquement pour les tests :
     qm start 200
   - Vérifier l'isolation AVANT tout test :
     # Depuis Kali :
     nmap -sn 10.10.10.0/24   → Résultat attendu : 0 hosts up
     nmap -sn 10.10.20.0/24   → Résultat attendu : 0 hosts up
     nmap -sn 10.10.30.0/24   → Résultat attendu : 0 hosts up
     ping 8.8.8.8              → OK (internet autorisé)
     curl https://kali.org     → OK (internet autorisé)
   - Documenter les résultats de scan comme preuve d'isolation
   - Exporter les résultats nmap en format XML pour le rapport :
     nmap -sn 10.10.10.0/24 -oX /tmp/scan-vlan10.xml
```

**Livrables GitHub** :
- `ansible/roles/hardening/` (SSH, Fail2ban, UFW)
- `docs/04-security-audit.md` (avec screenshots des scans Kali)

---

### Phase 5 : Automatisation & Infrastructure as Code

```
Tâches :

1. Scripts Bash :
   - scripts/00-proxmox-postinstall.sh :
     * Désactivation repo enterprise
     * Activation repo no-subscription
     * Suppression popup souscription
     * Mise à jour système
     * Configuration swap + swappiness
     * Installation paquets utiles (vim, htop, curl, git, fail2ban, tmux)
     * Hardening SSH de base
     * Affichage d'un résumé post-install (RAM, CPU, disque)

   - scripts/00-nas-setup.sh :
     * Installation paquets NFS + rsync + gpg + smartmontools
     * Création arborescence /backup/
     * Configuration exports NFS
     * Configuration UFW
     * Configuration SMART monitoring
     * Création cron de nettoyage des vieux backups
     * Test d'écriture NFS depuis le script

   - scripts/backup/backup-all-vms.sh :
     * vzdump de toutes les VMs/CTs actives
     * Compression zstd (meilleur ratio que lzo, moins de CPU que gzip)
     * rsync vers PC 2 (NAS) avec --partial (reprise en cas de coupure)
     * Rotation : 7 daily, 4 weekly
     * Notification en cas d'échec (webhook Discord ou email via msmtp)
     * Log dans un fichier + envoi métrique vers node_exporter textfile

   - scripts/backup/backup-databases.sh :
     * pg_dump de toutes les bases
     * Compression gzip
     * Chiffrement GPG (clé générée au setup)
     * Envoi vers PC 2 via rsync
     * Rotation 7 jours
     * Vérification d'intégrité (gunzip -t)

   - scripts/health-check.sh :
     * Vérifie que chaque CT/VM est running (qm/pct status)
     * Vérifie l'espace disque (alerte si > 80%)
     * Vérifie la RAM libre du host (alerte si < 15%)
     * Vérifie que les services critiques répondent :
       curl -sf http://10.10.20.30:3000/api/health  # Grafana
       curl -sf http://10.10.30.10:3000              # Forgejo
       curl -sf http://10.10.30.20:8000              # Woodpecker
     * Vérifie la connectivité NAS (ping + mount NFS)
     * Vérifie la santé SMART du disque NAS
     * Sortie JSON pour intégration monitoring
     * Code retour non-zéro si problème critique

2. Ansible :
   - Inventaire structuré par VLAN :
     inventory/
     ├── group_vars/
     │   ├── all.yml           # Variables globales (DNS, NTP, SSH port, domain)
     │   ├── services.yml      # Variables VLAN 20
     │   ├── cicd.yml          # Variables VLAN 30
     │   └── dmz.yml           # Variables VLAN 40
     └── hosts.ini :
         [management]
         proxmox    ansible_host=10.10.10.1
         nas        ansible_host=10.10.10.2

         [services]
         nginx      ansible_host=10.10.20.10
         postgresql ansible_host=10.10.20.20
         monitoring ansible_host=10.10.20.30

         [cicd]
         forgejo    ansible_host=10.10.30.10
         woodpecker ansible_host=10.10.30.20
         registry   ansible_host=10.10.30.30

         [dmz]
         kali       ansible_host=10.10.40.10

   - Playbooks :
     * site.yml — Déploie TOUT (orchestrateur principal)
     * playbooks/webserver.yml — Nginx reverse proxy
     * playbooks/database.yml — PostgreSQL + backup
     * playbooks/monitoring.yml — VictoriaMetrics + Grafana + Node Exporter
     * playbooks/cicd.yml — Forgejo + Woodpecker + Registry
     * playbooks/hardening.yml — SSH + Fail2ban + UFW sur tout
     * playbooks/nas.yml — Configuration du PC 2

   - Rôles réutilisables :
     * common/ — Mise à jour, paquets de base, NTP, locales, Node Exporter
     * hardening/ — SSH config, Fail2ban, UFW
     * webserver/ — Nginx + reverse proxy config + certificats
     * database/ — PostgreSQL + pg_hba + tuning + backup cron
     * monitoring/ — VictoriaMetrics + Grafana + dashboards
     * cicd/ — Forgejo + Woodpecker CI + Registry
     * backup/ — Scripts de backup + rotation + GPG

   - Ansible Vault pour les secrets :
     ansible-vault create inventory/group_vars/vault.yml
     # Stocker : mots de passe BDD, tokens API, secrets Woodpecker, clé GPG

3. Optionnel — Terraform :
   - Provider : bpg/proxmox (activement maintenu)
   - Définir chaque CT/VM en HCL :
     * Ressources (RAM, CPU), réseau (VLAN tag), storage
   - terraform plan → terraform apply pour recréer l'infra from scratch
   - Bon complément portfolio IaC même si moins critique en homelab
   - Stocker le state en local (pas besoin de backend S3 pour un homelab)
```

**Livrables GitHub** :
- `scripts/` (tous les scripts Bash)
- `ansible/` (inventaire, playbooks, rôles, vault)
- `terraform/` (optionnel)
- `docs/05-automation-iac.md`

---

### Phase 6 : Backup & Disaster Recovery

```
Tâches :

1. Backup Proxmox natif → PC 2 :
   - Configurer le storage NFS dans Proxmox :
     Datacenter > Storage > Add > NFS
     ID: nas-backup, Server: 10.10.10.2, Export: /backup/vzdump
     Content: VZDump backup file
   - Planifier via Datacenter > Backup :
     * Tous les jours à 02:00 — Mode snapshot — Compression zstd
     * Sélection : toutes les VMs/CTs (sauf Kali si éteinte)
     * Storage : nas-backup (PC 2)
     * Retention : keep-daily=7, keep-weekly=4
     * Email notification : en cas d'échec uniquement

2. Backup bases de données → PC 2 :
   - Cron sur le CT PostgreSQL (tous les jours à 01:00) :
     0 1 * * * /usr/local/bin/backup-databases.sh >> /var/log/backup-db.log 2>&1
   - Le script :
     * pg_dump de chaque base
     * Compression gzip
     * Vérification d'intégrité : gunzip -t fichier.sql.gz
     * Chiffrement GPG (clé générée au setup initial)
     * rsync vers PC 2 : /backup/databases/
     * Suppression des dumps > 7 jours en local
     * Écriture d'une métrique dans /var/lib/node_exporter/textfile/backup_db.prom :
       backup_db_last_success_timestamp <epoch>
       backup_db_last_size_bytes <size>
   - Sur PC 2, rotation :
     * Garder 7 daily + 4 weekly (script cron sur le NAS)

3. Backup configs :
   - Script hebdomadaire (dimanche 03:00) qui sauvegarde :
     * /etc/pve/ (config Proxmox — cluster, storage, VM configs)
     * /etc/network/interfaces
     * Export XML des règles pfSense (via l'API ou manuellement)
     * Liste des packages installés sur chaque CT :
       dpkg --get-selections > /backup/configs/CT_NAME-packages.txt
   - Destination : PC 2 /backup/configs/
   - Le repo Git Ansible constitue déjà un backup de la config logique

4. Test de restauration (DOCUMENTER !) :
   - Procédure testée : restaurer un CT depuis un backup vzdump
     qmrestore /mnt/pve/nas-backup/dump/vzdump-lxc-XXX.tar.zst NEWID --storage local
   - Procédure testée : restaurer une base PostgreSQL
     gpg -d backup.sql.gz.gpg | gunzip | psql -U postgres newdb
   - Scénario DR complet documenté :
     * Simuler la perte du CT Nginx
     * Restaurer depuis le backup sur PC 2
     * Vérifier le service (curl http://IP:80)
     * Mesurer le temps de restauration (RTO)
     * Vérifier la fraîcheur des données restaurées (RPO)
   - Documenter le RTO et RPO de chaque service dans un tableau :
     | Service | RPO | RTO estimé | RTO mesuré |
     |---------|-----|------------|------------|
     | Nginx   | 24h | 5 min      | X min      |
     | PostgreSQL | 24h | 10 min  | X min      |
     | ...     | ... | ...        | ...        |

5. Monitoring des backups :
   - Métriques exposées via node_exporter textfile collector :
     * backup_vzdump_last_success_timestamp
     * backup_db_last_success_timestamp
     * backup_nas_disk_free_bytes
   - Alertes Grafana :
     * Backup vzdump manquant (dernière métrique > 26h)
     * Backup BDD manquant (dernière métrique > 26h)
     * Espace disque NAS < 20%
   - Dashboard Grafana dédié "Backup Status" avec :
     * Dernière date de backup par type
     * Taille des backups (évolution dans le temps)
     * Espace disque NAS restant
```

**Livrables GitHub** :
- `scripts/backup/` (tous les scripts)
- `docs/06-backup-dr.md` (procédures + résultats de test DR + tableau RTO/RPO)

---

## 📁 Structure du repo GitHub

```
proxmox-secure-lab/
├── README.md
├── LICENSE (MIT)
├── .gitignore
├── CHANGELOG.md
│
├── docs/
│   ├── 00-hardware-setup.md
│   ├── 01-network-architecture.md
│   ├── 02-services-deployment.md
│   ├── 03-cicd-pipeline.md
│   ├── 04-security-audit.md
│   ├── 05-automation-iac.md
│   ├── 06-backup-dr.md
│   ├── DECISIONS.md              # Architecture Decision Records (ADR)
│   └── diagrams/
│       ├── network-topology.png
│       ├── architecture-overview.png
│       └── ram-budget.png
│
├── scripts/
│   ├── 00-proxmox-postinstall.sh
│   ├── 00-nas-setup.sh
│   ├── backup/
│   │   ├── backup-all-vms.sh
│   │   ├── backup-databases.sh
│   │   ├── backup-configs.sh
│   │   └── verify-backups.sh
│   └── health-check.sh
│
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── hosts.ini
│   │   └── group_vars/
│   │       ├── all.yml
│   │       ├── services.yml
│   │       ├── cicd.yml
│   │       ├── dmz.yml
│   │       └── vault.yml          # Secrets chiffrés Ansible Vault
│   ├── site.yml
│   ├── playbooks/
│   │   ├── webserver.yml
│   │   ├── database.yml
│   │   ├── monitoring.yml
│   │   ├── cicd.yml
│   │   ├── hardening.yml
│   │   └── nas.yml
│   └── roles/
│       ├── common/
│       ├── hardening/
│       ├── webserver/
│       ├── database/
│       ├── monitoring/
│       ├── cicd/
│       └── backup/
│
├── docker-compose/
│   ├── forgejo/docker-compose.yml
│   ├── woodpecker/docker-compose.yml
│   ├── monitoring/docker-compose.yml    # Alternative Docker au déploiement natif
│   └── registry/docker-compose.yml
│
├── terraform/ (optionnel)
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── pfsense/
│   └── firewall-rules-export.xml
│
└── .woodpecker.yml
```

---

## 📝 Template README.md pour GitHub

```markdown
# 🔒 Proxmox Secure Lab

> Environnement de test sécurisé et segmenté sur Proxmox VE,
> déployé sur deux laptops recyclés — Infrastructure as Code.

## 🎯 Objectif

Construire un homelab professionnel simulant un environnement de production
avec segmentation réseau, CI/CD, monitoring, hardening sécurité et disaster recovery.

## 💻 Hardware

| Machine | CPU | RAM | Stockage | Rôle |
|---------|-----|-----|----------|------|
| PC 1 | i5-8265U (4C/8T) | 8 Go | 250 Go SSD | Proxmox VE — Hyperviseur |
| PC 2 | i5-5200U (2C/4T) | 8 Go | 1 To HDD | Debian — NAS / Backup |

## 🏗️ Architecture

![Architecture](docs/diagrams/architecture-overview.png)

| VLAN | Réseau | Rôle | Services |
|------|--------|------|----------|
| 10 | 10.10.10.0/24 | Management | Proxmox UI, SSH, NAS |
| 20 | 10.10.20.0/24 | Services | Nginx, PostgreSQL, Grafana |
| 30 | 10.10.30.0/24 | CI/CD | Forgejo, Woodpecker CI, Registry |
| 40 | 10.10.40.0/24 | DMZ | Kali Linux (isolé) |

## 🛠️ Stack technique

- **Hyperviseur** : Proxmox VE 8.x (ext4)
- **Firewall** : pfSense CE (VM, 512 Mo)
- **Automatisation** : Ansible + Bash + Terraform (optionnel)
- **CI/CD** : Forgejo + Woodpecker CI + Docker Registry v2
- **Monitoring** : VictoriaMetrics + Grafana + Node Exporter
- **Backup** : vzdump → rsync chiffré GPG → NAS (PC 2)
- **Sécurité** : VLANs, pfSense, Fail2ban, UFW, Tailscale, MFA

## ⚡ Optimisation 8 Go RAM

Architecture optimisée avec **7 containers LXC + 2 VMs** pour tenir dans 8 Go :
- Containers LXC pour tous les services (10-50× plus léger qu'une VM)
- VictoriaMetrics au lieu de Prometheus (30-50% moins gourmand)
- VM Kali éteinte par défaut, démarrée à la demande
- Marge de 2,2 Go sans Kali — swap 4 Go en filet de sécurité

Détail du budget RAM : voir [docs/00-hardware-setup.md](docs/00-hardware-setup.md)

## 🚀 Déploiement rapide

\`\`\`bash
# 1. Post-installation Proxmox
bash scripts/00-proxmox-postinstall.sh

# 2. Setup NAS (PC 2)
bash scripts/00-nas-setup.sh

# 3. Déployer toute l'infrastructure
cd ansible/
ansible-playbook -i inventory/hosts.ini site.yml --ask-vault-pass
\`\`\`

## 📚 Documentation

| Phase | Document | Contenu |
|-------|----------|---------|
| 0 | [Hardware Setup](docs/00-hardware-setup.md) | Installation Proxmox + NAS |
| 1 | [Network](docs/01-network-architecture.md) | VLANs, pfSense, firewall rules |
| 2 | [Services](docs/02-services-deployment.md) | Nginx, PostgreSQL, Monitoring |
| 3 | [CI/CD](docs/03-cicd-pipeline.md) | Forgejo, Woodpecker, Registry |
| 4 | [Security](docs/04-security-audit.md) | Hardening, scans, isolation |
| 5 | [Automation](docs/05-automation-iac.md) | Ansible, scripts, Terraform |
| 6 | [Backup & DR](docs/06-backup-dr.md) | Procédures, RTO/RPO, tests |

## 🏗️ Architecture Decision Records

Les choix techniques sont documentés dans [docs/DECISIONS.md](docs/DECISIONS.md) :
- Pourquoi Forgejo plutôt que Gitea
- Pourquoi VictoriaMetrics plutôt que Prometheus
- Pourquoi ext4 plutôt que ZFS
- Pourquoi LXC plutôt que Docker partout

## 👤 Auteur

**Tom Daluzeau** — Alternant Administrateur Systèmes & DevOps
- GitHub : [@ton-github](https://github.com/ton-github)
- LinkedIn : [Tom Daluzeau](https://linkedin.com/in/tom-daluzeau)
```

---

## 🚀 Commandes Git pour initialiser le projet

```bash
# Créer le repo local
mkdir proxmox-secure-lab && cd proxmox-secure-lab
git init

# Créer la structure complète
mkdir -p docs/diagrams \
         scripts/backup \
         ansible/{inventory/group_vars,playbooks,roles/{common,hardening,webserver,database,monitoring,cicd,backup}} \
         docker-compose/{forgejo,woodpecker,monitoring,registry} \
         terraform \
         pfsense

# Créer les fichiers de base
touch README.md LICENSE CHANGELOG.md .gitignore docs/DECISIONS.md

# .gitignore
cat << 'EOF' > .gitignore
# Secrets
*.key
*.pem
*.crt
*secret*
*password*
.env
vault.yml
!ansible/inventory/group_vars/vault.yml  # le fichier vault est chiffré, ok

# Terraform
*.tfstate
*.tfstate.backup
.terraform/
.terraform.lock.hcl

# Ansible
*.retry

# Backups
*.vzdump
*.lzo
*.zst

# OS
.DS_Store
Thumbs.db

# GPG
*.gpg
*.asc

# Logs
*.log

# Editor
.vscode/
.idea/
*.swp
*~
EOF

# Premier commit
git add .
git commit -m "🎉 init: project structure for Proxmox Secure Lab v3 (Forgejo + Woodpecker + VictoriaMetrics)"

# Lier à GitHub
git remote add origin git@github.com:TON-USERNAME/proxmox-secure-lab.git
git branch -M main
git push -u origin main
```

---

## 💡 Conseils pour le portfolio

1. **Commite souvent** avec des messages conventionnels :
   - `feat: deploy pfSense with 4 VLANs`
   - `feat: add Forgejo + Woodpecker CI pipeline`
   - `feat: add VictoriaMetrics monitoring stack`
   - `docs: add network topology diagram`
   - `fix: reduce Grafana memory to fit budget`
   - `docs: add architecture decision records`
2. **Documente les galères** — Les recruteurs adorent voir la résolution de problèmes
3. **DECISIONS.md** — Un fichier ADR (Architecture Decision Records) qui explique *pourquoi* chaque choix technique. Ça montre une réflexion d'ingénieur, pas juste un tuto suivi.
4. **Ajoute des screenshots** dans `/docs/diagrams/` :
   - Proxmox dashboard avec les CTs/VMs et la conso RAM réelle
   - Grafana dashboards en fonctionnement
   - pfSense firewall rules
   - Résultat des scans Kali prouvant l'isolation VLAN
   - Pipeline Woodpecker en succès
5. **Écris un post LinkedIn** à chaque phase terminée
6. **Tag les versions** :
   - `git tag v0.1-network` après Phase 1
   - `git tag v0.2-services` après Phase 2
   - `git tag v1.0-complete` quand tout fonctionne
7. **Mets en avant la contrainte RAM** — Optimiser pour 8 Go montre une vraie compétence de sizing
8. **Documente le budget RAM réel** (via `free -h` et screenshots Proxmox) vs le théorique
9. **Compare v2 → v3** dans le CHANGELOG : montre que tu itères et modernises ta stack

---

## 📊 Changelog v2 → v3

| Changement | v2 | v3 | Raison |
|------------|----|----|--------|
| Git self-hosted | Gitea | **Forgejo** | Fork communautaire actif, gouvernance indépendante |
| CI/CD | Drone CI | **Woodpecker CI** | Fork open source actif, Drone quasi-abandonné |
| Monitoring | Prometheus (768 Mo) | **VictoriaMetrics** (512 Mo) | -256 Mo RAM, meilleure compression, PromQL compatible |
| Filesystem | ext4 + config ZFS inutile | **ext4 propre** | Suppression config ZFS ARC qui ne servait à rien |
| Marge RAM | 1,6 Go | **2,2 Go** | +600 Mo grâce aux optimisations stack |
| Secrets | Aucune gestion | **Ansible Vault** | Bonne pratique sécurité |
| Backup monitoring | Basique | **Métriques node_exporter** | Alertes Grafana automatiques si backup manquant |
| Disque NAS | Pas de monitoring | **SMART monitoring** | Surveillance santé du HDD |
| SSH hardening | Basique | **Étendu** | +ClientAlive, +X11Forwarding off, +AllowTcpForwarding |
| Documentation | Docs phases | **+ DECISIONS.md (ADR)** | Architecture Decision Records pour le portfolio |
| Health check | Basique | **+ Métriques JSON** | Intégration monitoring + code retour exploitable |
