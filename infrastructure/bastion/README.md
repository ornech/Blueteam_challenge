# README — répertoire `bastion`

Ce répertoire contient tout ce qu’il faut pour construire le *bastion* (jump-host) du labo. Le bastion est un container Docker connecté à **tous** les réseaux des labos et **seul** il expose un port SSH sur `127.0.0.1:2222`. L’utilisateur (prof) s’y connecte en SSH et crée des tunnels vers les Kibana / DVWA internes — ainsi les labs restent isolés entre eux.

---

## Objectifs

* Fournir un point d’accès central et contrôlé aux services internes de chaque labo (Kibana, DVWA, ...).
* Ne **pas** exposer les services des labs sur l’IP publique de l’hôte.
* Permettre au prof d’accéder facilement aux services via SSH tunnels (ou connexion interactive).
* Journaliser et contrôler les accès (auth par clé).

---

## Contenu du répertoire

```
bastion/
├─ Dockerfile                # image minimal SSH server
├─ authorized_keys           # clé publique(s) du prof (README: mettre la vôtre)
└─ make_tunnels.sh (optionnel) # exemple pour ouvrir tunnels (fournir si demandé)
```

> **Important** : `authorized_keys` doit contenir la/les clé(s) publique(s) du professeur. Ne mettez pas de mot de passe dans le container.

---

## Pré-requis

* Docker et docker-compose installés sur l’hôte.
* Clé SSH publique du prof prête (contenu à mettre dans `authorized_keys`).
* Le `docker-compose` principal associe le service `lab_bastion` à tous les réseaux des labs.

---

## Construire l'image bastion

Depuis le dossier parent (contenant `bastion/` et le `docker-compose.secure.yml`), ou depuis ce répertoire :

```bash
# depuis le dossier racine du projet
docker build -t lab_bastion:latest ./bastion
```

ou

```bash
# depuis le dossier bastion
cd bastion
docker build -t lab_bastion:latest .
```

---

## Préparer `authorized_keys`

1. Copie la clé publique du prof dans `bastion/authorized_keys`.
2. Assure-toi des permissions correctes (sur l'hôte) :

```bash
# place your public key in bastion/authorized_keys
chmod 400 bastion/authorized_keys
```

Le `docker-compose` va monter ce fichier dans `/root/.ssh/authorized_keys` du container.

---

## Démarrer le bastion via docker-compose

Si tu utilises `docker-compose.secure.yml` (qui inclut `lab_bastion`), lance :

```bash
docker compose -f docker-compose.secure.yml up -d
```

Vérifie que le bastion écoute bien sur `127.0.0.1:2222` :

```bash
# sur l'hôte
docker ps --format '{{.Names}} {{.Ports}}' | grep lab_bastion
ss -ltnp | grep 2222
# ou
sudo lsof -iTCP -sTCP:LISTEN -P | grep 2222
```

Tu dois voir une liaison sur `127.0.0.1:2222->22` (bind localhost).

---

## Se connecter au bastion (utilisation basique)

Depuis la machine hôte (ou depuis ta machine locale via SSH vers l'hôte), exécute :

```bash
ssh -p 2222 root@127.0.0.1
```

> Le Dockerfile est configuré pour permettre `PermitRootLogin yes` et `PasswordAuthentication no`. L’authentification se fait par clé publique (contenue dans `authorized_keys`).

---

## Accéder à Kibana / DVWA via tunnels (exemples)

### Tunnel pour Kibana lab1

Ouvre un tunnel local (sur ta machine) pour accéder à Kibana de lab1 :

```bash
ssh -p 2222 root@127.0.0.1 -L 5601:lab1_kibana:5601 -N
# ensuite ouvrir http://localhost:5601 dans ton navigateur
```

### Tunnel pour DVWA lab2

```bash
ssh -p 2222 root@127.0.0.1 -L 8082:lab2_dvwa:80 -N
# ouvrir http://localhost:8082
```

Tu peux ouvrir plusieurs tunnels en parallèle (dans plusieurs terminaux ou en arrière-plan). Choisis des ports locaux différents si tu crées plusieurs tunnels.

---

## Exemple d’entrée SSH dans `~/.ssh/config` (facilite usage)

Ajoute ceci dans ton `~/.ssh/config` (côté client/prof) :

```
Host lab-bastion
  HostName 127.0.0.1
  Port 2222
  User root
  IdentityFile ~/.ssh/id_rsa_prof
  ServerAliveInterval 60
```

Ensuite tu peux faire :

```bash
ssh lab-bastion -L 5601:lab1_kibana:5601 -N
```

---

## Utiliser `autossh` pour tunnels persistants (optionnel)

`autossh` redémarre automatiquement le tunnel si la connexion tombe :

```bash
# installer autossh
sudo apt install autossh

# ex.
autossh -M 0 -f -N -p 2222 root@127.0.0.1 -L 5601:lab1_kibana:5601
```

`-M 0` : disable monitoring port (useful pour containers). Ajuste selon besoin.

---

## Tests pour vérifier l’isolation (vérifications recommandées)

### 1) Depuis un attacker container (ex : lab2\_attacker) vérifier qu'on ne peut pas joindre lab1 par nom de conteneur

```bash
docker exec -it lab2_attacker bash -c "curl -sS --max-time 5 http://lab1_kibana:5601 || echo 'unreachable by name (ok)'"
```

### 2) Depuis un attacker container tenter d'accéder au bastion via host IP (devrait échouer si bastion bind sur 127.0.0.1)

```bash
docker exec -it lab2_attacker bash -c "curl -sS --max-time 5 http://$(hostname -I | awk '{print $1}'):2222 || echo 'host port not reachable from container (ok)'"
```

### 3) Depuis l'hôte, tester le tunnel

```bash
ssh -p 2222 root@127.0.0.1 -L 5601:lab1_kibana:5601 -N
# puis ouvrir http://localhost:5601
```

---

## Bonnes pratiques & sécurité (à appliquer)

* **Limiter l'accès au host** : ne pas exposer `127.0.0.1:2222` publiquement. Si l'accès doit être distant, place un VPN devant le host.
* **Utiliser des clés SSH à passphrase** et un agent SSH.
* **Ne jamais stocker de mot de passe en clair** dans le container.
* **Audit** : activer la journalisation (`/var/log/auth.log`) du bastion et exporter les logs hors du container.
* **Least privilege** : au lieu de `root`, créer un user non-root et lui donner sudo restreint si tu veux limiter l'empreinte.
* **Rotation des clés** : changer `authorized_keys` si nécessaire après chaque session publique.
* **Limiter forwarding** : si tu veux restreindre davantage, utilisez des options `authorized_keys` (command="", from="...") pour restreindre ce que chaque clé peut faire.

---

## Troubleshooting rapide

* `ss -ltnp | grep 2222` : vérifier binding port.
* `docker logs lab_bastion` : vérifier erreurs SSHD.
* `docker exec -it lab_bastion bash` puis `ss -tnlp` / `ping lab1_kibana` : debug réseau depuis bastion.
* Si tunnel ne marche pas : vérifier que `lab1_kibana` est résolu **depuis** le bastion (DNS de Docker) — dans le conteneur bastion, `ping lab1_kibana` doit fonctionner.

---

## Nettoyage

Pour arrêter le bastion (via docker-compose global) :

```bash
docker compose -f docker-compose.secure.yml down
```

ou si tu exécutes uniquement le service :

```bash
docker rm -f lab_bastion
docker network ls | grep labnet | awk '{print $1}' | xargs -r docker network rm
```

---

## Fichiers fournis (rappel)

* `Dockerfile` — image SSH simple.
* `authorized_keys` — **TU** dois mettre ici la clé publique du prof avant build / up.
