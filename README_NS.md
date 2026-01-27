# Lancer Docker GN <!-- omit in toc -->

- [Lancement en mode developpement](#lancement-en-mode-developpement)
  - [1) Sous-modules](#1-sous-modules)
    - [Initialiser les sous modules dans `/sources`](#initialiser-les-sous-modules-dans-sources)
    - [Mettre a jour les sous-modules apres modification de .gitmodules](#mettre-a-jour-les-sous-modules-apres-modification-de-gitmodules)
    - [Repartir de zero en cas d'erreurs submodules](#repartir-de-zero-en-cas-derreurs-submodules)
  - [2) Makefile pour dev](#2-makefile-pour-dev)
  - [3) Préparer le `.env`](#3-préparer-le-env)
  - [4) Initialiser config](#4-initialiser-config)
  - [5) Build et lancement](#5-build-et-lancement)
  - [6) Accès](#6-accès)
- [Déploiement en prod](#déploiement-en-prod)
  - [1) Pré-requis](#1-pré-requis)
  - [2) Vérifier le fichier `.env`](#2-vérifier-le-fichier-env)
  - [3) Initialiser les fichiers de config](#3-initialiser-les-fichiers-de-config)
  - [4) Se connecter au registry (si privé)](#4-se-connecter-au-registry-si-privé)
  - [5) Télécharger les images et démarrer](#5-télécharger-les-images-et-démarrer)
  - [6) Vérifier le demarrage](#6-vérifier-le-demarrage)
  - [7) Accès](#7-accès)


## Lancement en mode developpement

### 1) Sous-modules

#### Initialiser les sous modules dans `/sources`

NE PAS UTILISER la commande `make submodule_init`.
Il faut d'abord modifier le `.gitmodules`.

```yml
[submodule "GeoNature"]
	path = sources/GeoNature
	url = https://github.com/PnX-SI/GeoNature.git
	branch=develop #Ici préciser la branche de développement de l'ONF
[submodule "UsersHub"]
	path = sources/UsersHub
	url = https://github.com/PnX-SI/UsersHub.git
	branch = develop
[submodule "gn_module_export"]
	path = sources/gn_module_export
	url = https://github.com/PnX-SI/gn_module_export.git
[submodule "gn_module_dashboard"]
	path = sources/gn_module_dashboard
	url = https://github.com/PnX-SI/gn_module_dashboard.git
[submodule "gn_module_monitoring"]
	path = sources/gn_module_monitoring
	url = https://github.com/PnX-SI/gn_module_monitoring
	branch = develop #Ici préciser la branche de développement de l'ONF
```

#### Mettre a jour les sous-modules apres modification de .gitmodules

Objectif : initialiser et mettre a jour les sous-modules ET leurs sous-modules,
mais ne changer de branche QUE pour les sous-modules déclarés dans le .gitmodules
du parent.

1) Synchroniser la config locale avec .gitmodules :
```bash
git submodule sync --recursive
```

2) Initialiser et récupérer les sous-modules (et leurs sous-modules) :
```bash
git submodule update --init --recursive
```

3) Suivre les branches indiquées dans .gitmodules du parent (sans toucher
aux sous-modules imbriqués) :
```bash
git submodule foreach '
  branch=$(git config -f $toplevel/.gitmodules submodule.$name.branch)
  if [ -n "$branch" ]; then
    git fetch origin "$branch"
    git checkout -B "$branch" "origin/$branch"
  fi
'
```

Notes utiles :
- Si Git refuse le protocole file:// :
```bash
git -c protocol.file.allow=always submodule update --init --recursive
```
- Eviter `--depth 1` (clones shallow) car le commit épinglé peut manquer.
- Si un submodule est "shallow" et que des commits manquent :
```bash
git -C sources/GeoNature fetch --unshallow
```

#### Repartir de zero en cas d'erreurs submodules

Attention : cette procédure supprime les dossiers des submodules (perte des modifications locales).

```bash
git submodule deinit -f --all || true

rm -rf sources/GeoNature sources/UsersHub \
       sources/gn_module_export sources/gn_module_dashboard \
       sources/gn_module_monitoring

rm -rf .git/modules/GeoNature .git/modules/UsersHub \
       .git/modules/gn_module_export .git/modules/gn_module_dashboard \
       .git/modules/gn_module_monitoring

git submodule sync --recursive
git -c protocol.file.allow=always submodule update --init --recursive
```

Ensuite, si tu veux suivre les branches déclarées dans .gitmodules du parent :
```bash
git submodule foreach '
  branch=$(git config -f $toplevel/.gitmodules submodule.$name.branch)
  if [ -n "$branch" ]; then
    git fetch origin "$branch"
    git checkout -B "$branch" "origin/$branch"
  fi
'
```

### 2) Makefile pour dev

Créé un fichier `Makefile.local` à la racine du dépot pour y ajouter ses propres commandes make.


```bash
build_dev:
	COMPOSE_FILE=essential.yml:traefik-http.yml:dev.yml docker compose build base-backend base-frontend-source
	COMPOSE_FILE=essential.yml:traefik-http.yml:dev.yml docker compose build

init_config:
	jq '.projects.geonature.architect.build.configurations.development += {"baseHref": "/geonature/"}' sources/GeoNature/frontend/angular.json > angular.json.tmp && mv angular.json.tmp sources/GeoNature/frontend/angular.json # Pas une super pratique mais pas d'autre solution pour le moment
	source .env; echo "{\"API_ENDPOINT\":\"//$${GEONATURE_BACKEND_HOSTPORT}$${GEONATURE_BACKEND_PREFIX}\"}" > sources/GeoNature/frontend/src/assets/config.json

dev_up: init_config
	COMPOSE_FILE=essential.yml:traefik-http.yml:dev.yml docker compose up -d --force-recreate
```

- Ce que ca fait: build les images dev ( images de bases puis le reste des images).
- Quand l'utiliser: quand les images dev ont besoin des bases `*-wheels` et `*-source`.

### 3) Préparer le `.env`

Exemple de variables attendues pour un dev local classique :

```env
COMPOSE_FILE=essential.yml:traefik-http.yml:dev.yml
COMPOSE_PROFILES=db,usershub
POSTGRES_HOST=postgres
DOCKER_UID=1006
DOCKER_GID=1006
SKIP_POPULATE_DB=false
```

Variantes utiles :
- Base pre-build : `COMPOSE_PROFILES=pre-built-db,usershub` et `POSTGRES_HOST=geonature-pre-built-db`.
- Base externe : `COMPOSE_PROFILES=db-nopostgres,usershub` et `POSTGRES_HOST=<hote externe>`.

### 4) Initialiser config

Cette étape construit les fichiers de config avec les bon droits user :
```bash
sudo ./init_config.sh
```

### 5) Build et lancement

```bash
make build_dev
make dev_up
```

Si besoin de forcer un redémarrage :
```bash
COMPOSE_FILE=essential.yml:traefik-http.yml:dev.yml docker compose up -d --force-recreate
```

### 6) Accès

L'URL est basée sur `.env` :
```
${BASE_PROTOCOL}://${HOST}:${HTTP_PORT}${GEONATURE_FRONTEND_PREFIX}
```
Exemple : `http://hostname:8082/geonature`.

## Déploiement en prod

Cette section décrit un lancement en production a partir des images publiées sur un registry, en utilisant le `.env` fourni.
Pas besoin de `docker run` manuel : tout se fait avec `docker compose`.

### 1) Pré-requis

- Docker Engine + plugin `docker compose`.
- Acces reseau au registry (`registry.gitlab.com`) si images privées.
- DNS/route pour `${HOST}` et ouverture du port `${HTTP_PORT}`.

### 2) Vérifier le fichier `.env`

Points importants pour que la stack demarre :

- `COMPOSE_FILE=essential.yml:traefik-http.yml` (HTTP via traefik).  
  Pour HTTPS, utiliser `COMPOSE_FILE=essential.yml:traefik.yml` et configurer `ACME_EMAIL`.
- `COMPOSE_PROFILES` :
  - Base externe : `db-nopostgres,usershub` (le service `postgres` ne demarre pas).
  - Base dockerisee : `db,usershub` et `POSTGRES_HOST=postgres`.
- `DOCKER_UID` / `DOCKER_GID` :
  ```bash
  DOCKER_UID=$(id -u)
  DOCKER_GID=$(id -g)
  ```
- `POSTGRES_HOST`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` : verifier acces et droits.
- `SKIP_POPULATE_DB` : doit etre `false` au premier lancement si vous voulez initialiser la base.

### 3) Initialiser les fichiers de config

```bash
# Run as root so ownership/permissions are applied on host volumes
sudo ./init-config.sh
# Ensure DOCKER_GID is a shared maintainer group (example for ONF : ns_geonature),
# and maintainer users belong to that group (umask 002 recommended)
```

### 4) Se connecter au registry (si privé)

```bash
docker login registry.gitlab.com
```

### 5) Télécharger les images et démarrer

Recommandé pour valider l'acces au registry :
```bash
docker compose pull
```

Puis démarrer :
```bash
docker compose up -d --remove-orphans
```

Notes :
- `docker compose up -d` suffit si les images n'existent pas encore : Docker fera le pull automatiquement.
- Pour forcer une MAJ d'images : `docker compose pull` puis `docker compose up -d --remove-orphans`.

### 6) Vérifier le demarrage

```bash
docker compose ps
docker compose logs -f --tail 100 geonature-backend
```

Le service `geonature-install-db` doit finir avec un statut `0`. En cas d'erreur :
```bash
docker compose logs -f geonature-install-db
```

### 7) Accès

URL d'acces (à adapter en fonction de l'où on appelle cette url) :
```
${GEONATURE_FRONTEND_PROTOCOL}://${GEONATURE_FRONTEND_HOSTPORT}${GEONATURE_FRONTEND_PREFIX}
```
Exemple : `https://hostname/geonature`.
