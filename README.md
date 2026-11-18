# 🎶 Player

[![CI](https://github.com/ItsMariusBC/iLoveMusic/actions/workflows/ci.yml/badge.svg?branch=developpment)](https://github.com/ItsMariusBC/iLoveMusic/actions/workflows/ci.yml)
[![Image](https://img.shields.io/badge/ghcr.io-itsmariusbc%2Fplayer-blue?logo=docker)](https://github.com/ItsMariusBC/iLoveMusic/pkgs/container/player)
![Node](https://img.shields.io/badge/node-24-339933?logo=node.js&logoColor=white)
![React](https://img.shields.io/badge/react-19-61DAFB?logo=react&logoColor=black)
![TypeScript](https://img.shields.io/badge/typescript-strict-3178C6?logo=typescript&logoColor=white)

Lecteur musical personnel, auto-hébergé, pensé pour le travail : un catalogue privé, une lecture continue sans friction, et un panneau d'administration pour gérer la bibliothèque sans quitter le navigateur.

Une seule image Docker sert l'interface et l'API. L'authentification passe par OpenID Connect (Authentik), les données vivent dans un seul volume.

---

## ✨ Fonctionnalités

|                           |                                                                                                                                                                                      |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 🎧 **Lecture continue**   | File d'attente issue du catalogue, pré-chargement du titre suivant, reprise du dernier titre et de sa position au rechargement.                                                      |
| ⌨️ **Contrôles natifs**   | Media Session : touches multimédia, écran de verrouillage, raccourcis clavier (`Espace`, `↑ ↓`, `← →`, `M`).                                                                         |
| 🔊 **Volume normalisé**   | Cible -14 LUFS d'après une mesure ffmpeg (EBU R128) faite à l'import.                                                                                                                |
| 📱 **Qualité adaptative** | Variante AAC allégée pour le mobile, réglage Auto / Max / Allégée, cache HTTP (`ETag`, `304`, `If-Range`).                                                                           |
| 🎨 **Fond vivant**        | Dégradé WebGL dérivé de la pochette, rendu à la demande à 30 i/s ; fond statique sous `prefers-reduced-motion`.                                                                      |
| 🗂️ **Administration**     | Dossiers (créer, renommer, déplacer, glisser-déposer), import FLAC / MP3 / WAV par fichier, dossier ou URL, édition par lot, pochettes et métadonnées (MusicBrainz, Deezer, iTunes). |
| 🙋 **Demandes de sons**   | Tout utilisateur propose un titre ; les administrateurs valident, importent ou refusent avec un motif.                                                                               |
| 🛡️ **Accès par groupes**  | OIDC + groupes `admin` et `users` ; `/api/admin/*` répond 403 aux autres.                                                                                                            |
| 🩺 **Exploitation**       | `/healthz`, entretien automatique des données, sauvegarde par volume, image en lecture seule.                                                                                        |

---

## 🧱 Stack

- **Front** : React 19, TypeScript, Vite 8, Tailwind CSS 4, Framer Motion, React Three Fiber.
- **API** : Node 24, Hono, SQLite natif (`node:sqlite`), openid-client, ffmpeg.
- **Outillage** : Yarn 1.22, Bun (tests unitaires), Playwright (tests navigateur), oxlint, oxfmt.

---

## 🚀 Démarrage rapide

Prérequis : Node `24` (voir `.node-version`), Yarn `1.22.22`, Bun (voir `.bun-version`), ffmpeg pour la mesure du volume en local.

```sh
yarn install --frozen-lockfile
yarn dev
```

`yarn dev` lance en parallèle :

| Service      | URL                     | Rôle                                                                         |
| ------------ | ----------------------- | ---------------------------------------------------------------------------- |
| Vite         | `http://localhost:3000` | Interface, proxy `/api` vers l'API                                           |
| API          | `http://localhost:8080` | Serveur Hono, configuré par `.env.development` (versionné, sans secret réel) |
| OIDC factice | `http://localhost:3002` | Fournisseur de test                                                          |

Comptes de test sur l'écran de connexion factice : `admin@test` (groupe admin), `user@test` (groupe users), `nobody@test` (accès refusé).

> 💡 Avec `DEV_BYPASS_LOGIN=true` (activé dans `.env.development`), l'écran propose « Entrer en admin » et « Entrer en user » sans passer par l'OIDC. Le serveur refuse de démarrer avec ce réglage en `NODE_ENV=production`.

Pour remplir le catalogue de développement depuis des fichiers audio existants :

```sh
DATA_DIR=./.data yarn migrate:catalog <dossier-de-musique> [--manifest <fichier.json>]
```

---

## 🧪 Qualité et tests

```sh
yarn validate                      # lint, format, types, tests unitaires, tests serveur, build
yarn playwright install chromium
yarn test:e2e                      # tests navigateur sur le build dist/
```

| Commande                          | Contenu                                                  |
| --------------------------------- | -------------------------------------------------------- |
| `yarn lint` / `yarn format:check` | oxlint et oxfmt                                          |
| `yarn typecheck`                  | Front et serveur                                         |
| `yarn test`                       | Tests unitaires (Bun)                                    |
| `yarn test:server`                | Tests de l'API (`node --test`)                           |
| `yarn test:e2e`                   | Playwright, catalogue seedé depuis `tests/e2e/fixtures/` |

Les tests navigateur tournent avec `reducedMotion: "reduce"` : pas de scène WebGL, donc un comportement identique sur un poste et sur un runner CI sans GPU.

---

## 🐳 Docker

### Lancer l'image en local

```sh
cp .env.example .env   # renseigner APP_URL, OIDC_*, SESSION_SECRET
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build --wait
```

Ouvrir `http://127.0.0.1:8080`. `PLAYER_PORT` change le port publié, `PLAYER_DATA_PATH` monte `/data` depuis un dossier de l'hôte (propriétaire uid 101).

Pour un essai en `http://` avec le fournisseur factice lancé sur l'hôte (`MOCK_OIDC_ISSUER=http://host.docker.internal:3002 yarn dev:oidc`) :

```sh
docker compose -f docker-compose.yml -f docker-compose.ci.yml up -d --build --wait
sh scripts/ci/stack-check.sh   # les mêmes contrôles que la CI
```

### Variables d'environnement

| Variable                                | Obligatoire | Défaut            | Rôle                                                                                           |
| --------------------------------------- | :---------: | ----------------- | ---------------------------------------------------------------------------------------------- |
| `APP_URL`                               |     ✅      |                   | Origine publique (`https://` en production). Redirection OIDC : `${APP_URL}/api/auth/callback` |
| `OIDC_ISSUER`                           |     ✅      |                   | URL de l'application Authentik                                                                 |
| `OIDC_CLIENT_ID` / `OIDC_CLIENT_SECRET` |     ✅      |                   | Identifiants du client confidentiel                                                            |
| `SESSION_SECRET`                        |     ✅      |                   | 32 octets en hexadécimal : `openssl rand -hex 32`                                              |
| `PORT`                                  |             | `8080`            | Port d'écoute                                                                                  |
| `DATA_DIR`                              |             | `/data`           | Base SQLite et médias                                                                          |
| `OIDC_GROUPS_CLAIM`                     |             | `groups`          | Revendication portant les groupes                                                              |
| `OIDC_GROUP_ADMIN` / `OIDC_GROUP_USERS` |             | `admin` / `users` | Groupes donnant accès                                                                          |
| `SESSION_TTL_HOURS`                     |             | `12`              | Durée de session                                                                               |
| `MAX_UPLOAD_MB`                         |             | `200`             | Taille maximale d'un import                                                                    |
| `MAINTENANCE_INTERVAL_HOURS`            |             | `24`              | Entretien des données (`0` désactive)                                                          |
| `MIN_FREE_MB`                           |             | `500`             | Seuil d'espace libre sous lequel `/healthz` répond 503                                         |
| `FFMPEG_PATH`                           |             | `ffmpeg`          | Binaire ffmpeg                                                                                 |
| `NODE_ENV`                              |             | `production`      | `development` autorise `http://`                                                               |

Le modèle complet est dans [`.env.example`](.env.example).

### Ce que contient l'image

- 🪶 Alpine nu + le seul binaire Node 24 : ni npm, ni yarn, ni corepack dans l'image livrée. Images de base épinglées par digest.
- 🔒 Utilisateur `101`, fichiers applicatifs appartenant à root, système de fichiers en lecture seule, `cap_drop: ALL`, `no-new-privileges`, `/tmp` éphémère (voir `docker-compose.yml`). Seul `/data` est inscriptible.
- 📦 Multi-étapes : build Vite + tsc, dépendances de production seules installées avec `--ignore-scripts` (le front est bundlé, React et three.js ne sont pas embarqués), image finale avec ffmpeg.
- ⚡ Cache Yarn monté pendant le build (`--mount=type=cache`) : une dépendance modifiée ne retélécharge que le delta.
- 🩺 `HEALTHCHECK` sur `/healthz` ; `503 degraded` veut dire « alerter, ne pas redémarrer ».

Mesures sur un poste de développement (Apple Silicon, cache BuildKit vidé pour le build à froid) :

|                                                           |  Avant |  Après |
| --------------------------------------------------------- | -----: | -----: |
| Taille de l'image                                         | 446 Mo | 347 Mo |
| Build à froid                                             |   44 s |   22 s |
| Reconstruction après un changement de dépendance          |   27 s |    4 s |
| Vulnérabilités HIGH / CRITICAL (trivy, OS et paquets npm) |     41 |      0 |

Vérifier soi-même : `hadolint Dockerfile`, `trivy image player:local`, et la pile Compose ci-dessus avec `scripts/ci/stack-check.sh`.

---

## 🚢 Branches et livraison

| Branche        | Rôle                                                          |
| -------------- | ------------------------------------------------------------- |
| `developpment` | Branche par défaut, intégration du travail courant            |
| `production`   | Version mise en ligne, alimentée par PR depuis `developpment` |

- Les PR vers ces deux branches doivent passer `CI required` (lint, scans gitleaks et trivy, build, pile Docker, tests).
- Un tag `vX.Y.Z` sur `production` publie l'image `ghcr.io/itsmariusbc/player` (`linux/amd64`, `linux/arm64`) et la release GitHub.

Détails, déploiement Dokploy, sauvegarde et retour arrière : [docs/ci.md](docs/ci.md).

---

## 🗺️ Architecture

```
components/   Interface React (lecteur, administration, demandes, dégradé)
lib/          Moteur audio, contrôleurs, catalogue, hooks
server/src/   API Hono : auth OIDC, catalogue, médias, administration, demandes
tests/        Unitaires (Bun) et navigateur (Playwright)
scripts/      Contrôles CI et démarrage e2e
docs/         Architecture, CI/CD, plans
```

Couches du lecteur, routes de l'API, chorégraphie d'un changement de piste : [docs/architecture.md](docs/architecture.md).

---

## 🛠️ Administration en bref

- 📁 **Dossiers** : créer, renommer, supprimer ; réordonner et imbriquer par glisser-déposer.
- ⬆️ **Imports** : fichier, dossier entier ou URL https, traités l'un après l'autre côté serveur ; les doublons (SHA-256) sont refusés.
- ✏️ **Édition** : titre, artiste, album, dossier, pochette, par titre ou par lot. MP3 et FLAC voient leurs tags réécrits, WAV jamais.
- 🔎 **Métadonnées** : complétion depuis MusicBrainz, Deezer et iTunes (sortie HTTPS requise, le reste fonctionne sans).
- 🔊 **Volume et lecture allégée** : passes d'analyse et d'encodage lancées depuis l'onglet Catalogue (ffmpeg requis).
- 🧹 **Entretien** : répertoires orphelins et historique d'imports, au démarrage puis toutes les `MAINTENANCE_INTERVAL_HOURS` heures.
