# Guide Phase 1 — OPNsense, VLANs et Tailscale

> **Date** : 16 février 2026
> **Objectif** : Comprendre tout ce qu'on a fait, pourquoi, et comment ça fonctionne ensemble
> **Prérequis** : Phase 0 terminée (Proxmox + Debian NAS installés et accessibles)

---

## Vue d'ensemble : Qu'est-ce qu'on a construit ?

```
            INTERNET
               │
          ┌────┴────┐
          │  BOX     │  192.168.1.254 (ta passerelle internet)
          └────┬────-┘
               │
               │  Réseau physique 192.168.1.0/24
               │
    ┌──────────┼──────────────────────────────┐
    │          │                              │
    │   ┌──────┴──────┐              ┌────────┴───────┐
    │   │ PC Windows  │              │  NAS (PC 2)    │
    │   │ 192.168.1.x │              │  192.168.1.101 │
    │   └─────────────┘              └────────────────┘
    │
    │   ┌─────────────────────────────────────────┐
    │   │         PC 1 — Proxmox VE 9.1           │
    │   │         192.168.1.100                    │
    │   │                                          │
    │   │   ┌──────────────────────────────────┐   │
    │   │   │    VM 100 — OPNsense 26.1        │   │
    │   │   │                                  │   │
    │   │   │  WAN (vtnet0) = 192.168.1.81     │   │
    │   │   │  LAN (vtnet1) = 10.0.0.1         │   │
    │   │   │  MGMT (vlan10) = 10.0.10.1       │   │
    │   │   │  SERVICES (vlan20) = 10.0.20.1   │   │
    │   │   │  CICD (vlan30) = 10.0.30.1       │   │
    │   │   │  Tailscale VPN = actif            │   │
    │   │   └──────────────────────────────────┘   │
    │   │                                          │
    │   │  vmbr0 (bridge VLAN-aware)               │
    │   └─────────────────────────────────────────-┘
    │
    └── Tailscale (VPN mesh) → accessible depuis n'importe où
```

En résumé : on a créé un firewall/routeur virtuel (OPNsense) à l'intérieur de Proxmox qui sépare ton lab en réseaux isolés (VLANs), avec un VPN pour y accéder à distance.

---

## Partie 1 : Le bridge VLAN-aware (vmbr0)

### C'est quoi un bridge ?

Un bridge c'est un **switch virtuel**. Imagine un multiprise réseau logicielle. Quand tu crées une VM ou un container dans Proxmox, il se "branche" sur ce switch virtuel pour accéder au réseau.

`vmbr0` est le bridge par défaut de Proxmox. Il est relié à ton interface physique (l'adaptateur USB-C Ethernet), ce qui permet aux VMs de communiquer avec le monde extérieur.

### C'est quoi VLAN-aware ?

Quand tu actives "VLAN-aware" sur vmbr0, le bridge devient intelligent : il sait **trier les paquets réseau par étiquette** (le VLAN tag).

Sans VLAN-aware, tu aurais besoin d'un bridge séparé par réseau (vmbr0, vmbr1, vmbr2...). Avec VLAN-aware, un seul bridge suffit — chaque VM ou container reçoit juste un numéro de VLAN et le bridge fait le tri.

C'est exactement comme un switch manageable en entreprise avec des ports assignés à différents VLANs, mais en virtuel.

### Ce qu'on a fait

Dans la Web UI Proxmox → System → Network → vmbr0 → Edit → coché "VLAN aware" → Apply.

**Une action, mais elle débloque tout le reste** : sans ça, impossible de segmenter le réseau.

---

## Partie 2 : La VM OPNsense

### Pourquoi un firewall dans une VM ?

Dans un datacenter réel, le firewall est une machine physique dédiée (un boîtier Fortinet, Cisco ASA, etc.). Dans un homelab, on n'a pas ce luxe — on virtualise le firewall dans Proxmox.

OPNsense est un **système d'exploitation complet** basé sur FreeBSD. Ce n'est pas un simple logiciel qu'on installe : c'est un OS entier dédié à être un firewall/routeur. Il remplace ta box internet pour le réseau interne du lab.

### Pourquoi OPNsense a besoin de deux interfaces réseau ?

Un firewall est par définition **entre** deux réseaux. Il a besoin de deux "pattes" :

- **WAN (vtnet0)** : la patte qui regarde vers l'extérieur (ta box, internet). IP : `192.168.1.81` attribuée par ta box en DHCP.
- **LAN (vtnet1)** : la patte qui regarde vers l'intérieur (ton lab). C'est sur cette interface qu'on a créé les VLANs.

Tout le trafic entre l'intérieur et l'extérieur **doit passer par OPNsense**. C'est lui qui décide ce qui passe et ce qui ne passe pas.

### Le processus d'installation

1. **Upload de l'ISO** dans Proxmox (comme mettre une clé USB dans un PC)
2. **Création de la VM** avec 2 interfaces réseau (net0 = WAN, net1 = LAN)
3. **Boot sur l'ISO** → système live en RAM (rien sur le disque)
4. **Lancement de l'installeur** (compte `installer`/`opnsense` ou manuellement via `opnsense-installer`)
5. **Choix du disque** : `ada0` (le disque virtuel de 8 Go), PAS `cd0` (le lecteur CD = l'ISO)
6. **Retrait de l'ISO** après installation (sinon ça reboote sur l'installeur à chaque fois)
7. **Boot sur le disque** → OPNsense opérationnel

**Erreur qu'on a rencontrée** : 512 Mo de RAM étaient insuffisants pour l'installation (copie du live image). Solution : monter temporairement à 3 Go, installer, puis redescendre.

### Configuration initiale des interfaces

Depuis la console texte d'OPNsense :

- Option **1** (Assign interfaces) → vtnet0 = WAN, vtnet1 = LAN
- Option **2** (Set interface IP) → WAN en DHCP (reçoit une IP de ta box), LAN en statique

---

## Partie 3 : Les VLANs

### C'est quoi un VLAN ?

Un VLAN (Virtual LAN) c'est un **réseau virtuel isolé**. Les machines sur le VLAN 10 ne peuvent pas parler aux machines sur le VLAN 20, même si physiquement elles sont connectées au même câble/switch.

C'est comme avoir plusieurs réseaux physiques séparés, mais sans acheter plusieurs switches.

### Pourquoi segmenter en VLANs ?

**Sécurité** : si un container est compromis sur le VLAN 20 (Services), l'attaquant ne peut pas atteindre les machines du VLAN 10 (Management) où se trouvent Proxmox et le NAS. C'est le principe du **moindre privilège** appliqué au réseau.

**Organisation** : chaque rôle a son réseau, c'est clair et propre.

### Nos VLANs

| VLAN | Nom | Sous-réseau | Passerelle | Rôle |
|------|-----|-------------|------------|------|
| 10 | MGMT | 10.0.10.0/24 | 10.0.10.1 | Administration : Proxmox UI, SSH, NAS |
| 20 | SERVICES | 10.0.20.0/24 | 10.0.20.1 | Services : Nginx, PostgreSQL, Monitoring |
| 30 | CICD | 10.0.30.0/24 | 10.0.30.1 | CI/CD : Forgejo, Woodpecker, Registry |

On a aussi gardé le LAN de base en `10.0.0.1/24` comme réseau de secours.

### Comment on les a créés

1. **Interfaces → Other Types → VLAN** : on crée les VLANs (parent = vtnet1, tag = 10/20/30)
2. **Interfaces → Assignments** : on assigne chaque VLAN comme interface OPNsense (OPT1, OPT2, OPT3)
3. **On active et configure chaque interface** : IP statique, rename (MGMT, SERVICES, CICD)

### Le DHCP (Kea DHCP)

Pour chaque VLAN, OPNsense distribue des IPs automatiquement via DHCP :

| VLAN | Plage DHCP | Usage |
|------|-----------|-------|
| MGMT | 10.0.10.100 - 10.0.10.200 | IPs dynamiques |
| SERVICES | 10.0.20.100 - 10.0.20.200 | IPs dynamiques |
| CICD | 10.0.30.100 - 10.0.30.200 | IPs dynamiques |

Pourquoi commencer à `.100` ? Les adresses `.1` à `.99` sont réservées pour les IPs fixes (serveurs, Proxmox, NAS). Les adresses `.201` à `.254` sont en réserve.

---

## Partie 4 : Les règles firewall

### Comment fonctionne le firewall

OPNsense utilise **pf** (packet filter), le firewall de FreeBSD. Les règles sont évaluées **de haut en bas**, et la première règle qui match gagne. Si aucune règle ne match, le paquet est **bloqué par défaut**.

Chaque interface a ses propres règles. Le trafic entrant sur une interface est filtré par les règles de cette interface.

### Ce qu'on a configuré

**Sur chaque VLAN (MGMT, SERVICES, CICD) :**
- Une règle "Allow all (temp)" → autorise tout le trafic. C'est temporaire pour que tout fonctionne pendant la mise en place. On affinera plus tard.

**Sur le WAN :**
- Décoché "Block private networks" et "Block bogon networks". Normalement ces règles protègent contre le trafic qui ne devrait pas venir d'internet. Mais notre WAN est sur un réseau local privé (192.168.1.x), donc ces règles bloquaient notre propre trafic.
- Ajouté "Allow WebGUI from LAN (temp)" → autorise l'accès à la Web GUI depuis 192.168.1.0/24 sur le port 443 (HTTPS).

### L'erreur qu'on a rencontrée

Notre règle "Allow WebGUI" ne fonctionnait pas parce que la règle "Block private networks" était **au-dessus** et bloquait tout le trafic depuis 192.168.1.0/24 avant que notre règle soit évaluée. Solution : désactiver "Block private networks" sur le WAN.

**Leçon** : l'ordre des règles firewall est crucial. Premier match = décision finale.

### pfctl — le contrôle du firewall en CLI

- `pfctl -d` → **désactive** le firewall (tout passe, dangereux mais utile pour debugger)
- `pfctl -e` → **réactive** le firewall

---

## Partie 5 : Le NAT (Network Address Translation)

### Le problème

Les machines du lab ont des IPs en `10.0.x.x`. Internet ne sait pas router ces adresses — ce sont des adresses privées (RFC 1918). Comment un container en `10.0.20.50` peut-il aller sur internet ?

### La solution : le NAT

OPNsense traduit l'adresse source avant d'envoyer le paquet sur internet :

```
Container (10.0.20.50) veut aller sur google.com
    │
    ▼
OPNsense reçoit le paquet sur l'interface SERVICES (10.0.20.1)
    │
    ▼
OPNsense remplace l'adresse source :
    10.0.20.50 → 192.168.1.81 (son adresse WAN)
    │
    ▼
La box reçoit le paquet depuis 192.168.1.81
    │
    ▼
La box remplace encore :
    192.168.1.81 → ton IP publique
    │
    ▼
Google reçoit le paquet, répond
    │
    ▼
Le chemin inverse se fait automatiquement
```

Il y a donc **double NAT** dans ton lab : OPNsense fait un premier NAT, ta box en fait un deuxième. C'est normal pour un homelab.

### Le "reverse NAT" (port forwarding)

Tu avais posé la question : oui, ça existe. C'est le **port forwarding** (ou DNAT). Ça permet de dire "tout ce qui arrive sur le port 80 de mon IP WAN, envoie-le vers 10.0.20.50 port 80". On l'utilisera quand on exposera des services.

---

## Partie 6 : Tailscale (VPN)

### Le problème

Tu veux accéder à ton lab (Proxmox, OPNsense) depuis n'importe où (cours, café, etc.). Mais ton lab est derrière ta box, sur un réseau privé. Ouvrir des ports sur ta box serait dangereux.

### La solution : Tailscale

Tailscale crée un **réseau privé virtuel mesh** basé sur WireGuard. Chaque machine qui installe Tailscale rejoint ce réseau et peut communiquer avec les autres, même derrière des NATs et des pare-feux, sans ouvrir aucun port.

```
┌─────────────────────────────┐
│       Réseau Tailscale      │
│                             │
│  PC Portable (en cours)     │
│       ↕ tunnel chiffré      │
│  OPNsense (chez toi)        │
│       → route vers :        │
│         192.168.1.0/24      │
│         10.0.10.0/24        │
│         10.0.20.0/24        │
│         10.0.30.0/24        │
└─────────────────────────────┘
```

### Ce qu'on a fait

1. **Installé le plugin** `os-tailscale` sur OPNsense
2. **Activé** dans VPN → Tailscale
3. **Configuré les routes** avec `tailscale up --advertise-routes=...`
   - Ça dit à Tailscale : "je sais comment atteindre ces réseaux, fais passer le trafic par moi"
4. **Approuvé les routes** dans l'admin Tailscale (login.tailscale.com)
5. **Installé Tailscale sur le PC Windows**

Résultat : depuis n'importe quel réseau, ton PC avec Tailscale peut accéder à `https://192.168.1.100:8006` (Proxmox) et `https://192.168.1.81` (OPNsense).

---

## Partie 7 : OPNsense = 3 rôles en 1

OPNsense remplit trois fonctions essentielles pour ton lab :

### 1. Routeur
Il fait passer le trafic **entre les réseaux** :
- VLAN 10 ↔ VLAN 20 (si autorisé par le firewall)
- VLANs → internet (via NAT)
- Internet → VLANs (via port forwarding, si configuré)

Sans routeur, chaque VLAN serait une île isolée sans accès à rien.

### 2. Firewall
Il **filtre** le trafic selon des règles :
- Qui peut parler à qui ?
- Sur quels ports ?
- Dans quelle direction ?

Par défaut tout est bloqué (deny all). On ouvre ce dont on a besoin.

### 3. Serveur DHCP + DNS
- **DHCP** : distribue automatiquement des IPs aux machines qui se connectent
- **DNS** : résout les noms de domaine (google.com → IP) et enregistre les noms locaux (forgejo.lab.local → 10.0.20.x)

---

## Récap des fichiers et commandes importants

### Commandes OPNsense (console)

| Commande | Rôle |
|----------|------|
| `1` | Assigner les interfaces (WAN/LAN) |
| `2` | Configurer les IPs des interfaces |
| `7` | Ping (tester la connectivité) |
| `8` | Shell (accès ligne de commande) |
| `pfctl -d` | Désactiver le firewall (debug) |
| `pfctl -e` | Réactiver le firewall |
| `tailscale up --advertise-routes=...` | Configurer les routes Tailscale |
| `opnsense-update` | Mettre à jour OPNsense |
| `opnsense-installer` | Relancer l'installeur |

### Navigation Web GUI OPNsense

| Menu | Usage |
|------|-------|
| Interfaces → Assignments | Assigner et configurer les interfaces |
| Interfaces → Other Types → VLAN | Créer des VLANs |
| Firewall → Rules | Créer des règles de filtrage par interface |
| Services → Kea DHCP | Configurer le serveur DHCP par subnet |
| System → Firmware → Plugins | Installer des extensions (Tailscale, etc.) |
| VPN → Tailscale | Configurer le VPN |

---

## Ce qui reste à faire

La Phase 1 n'est pas tout à fait terminée. Il reste :

- [ ] **Réduire la RAM** d'OPNsense de 3072 Mo à 512 Mo (c'était temporaire pour l'installation)
- [ ] **Tester les VLANs** : créer un container sur le VLAN 20, vérifier qu'il reçoit une IP en 10.0.20.x
- [ ] **Affiner les règles firewall** : remplacer les "Allow all (temp)" par des règles précises
- [ ] **Configurer le routage inter-VLAN** : définir quel VLAN peut parler à quel autre
- [ ] **Supprimer la règle WAN temporaire** quand Tailscale est le seul moyen d'accès distant

---

## Erreurs rencontrées et leçons

| Erreur | Cause | Leçon |
|--------|-------|-------|
| Installation échoue (device busy) | Tentative précédente avait verrouillé le disque | Supprimer la VM et repartir de zéro si le disque est bloqué |
| Installation échoue (pas assez de RAM) | 512 Mo insuffisants pour copier le live image | Monter la RAM temporairement pour l'install, redescendre après |
| Login `installer` ne fonctionne plus | Déjà utilisé ou installation échouée | Utiliser `root`/`opnsense` → Shell → `opnsense-installer` |
| Web GUI inaccessible avec firewall actif | Règle "Block private networks" bloque 192.168.1.x | Désactiver cette règle quand le WAN est sur un réseau privé |
| Conflit IP 10.0.10.1 | LAN et VLAN 10 avaient la même IP | Changer le LAN de base en 10.0.0.1 pour éviter le conflit |
| Plugin ne s'installe pas | OPNsense pas à jour | Mettre à jour avec `pkg update && pkg upgrade` avant d'installer |