# syntax=docker/dockerfile:1.7
# Image unique : le build Vite et l'API Hono, servis par Node sur le port 8080.
# Étapes : dépendances complètes (build), dépendances de production, image finale sur Alpine nu
# avec le seul binaire Node (ni npm, ni yarn, ni corepack dans l'image livrée).
ARG NODE_IMAGE=node:24.22.3-alpine3.24@sha256:116b800c3754b440ee0aa3ed2f20f5bf3d99a554bfd9adeea09ea8017f6e85f5
# Même Alpine que l'image Node ci-dessus (3.24) : le binaire Node y trouve musl et libstdc++ identiques.
ARG ALPINE_IMAGE=alpine:3.24.4@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf

# --- Build : toutes les dépendances, puis Vite + tsc -------------------------------------------
FROM ${NODE_IMAGE} AS build
WORKDIR /app
COPY package.json yarn.lock ./
# Le cache Yarn survit d'un build à l'autre : un lockfile modifié ne retélécharge que le delta.
RUN --mount=type=cache,target=/usr/local/share/.cache/yarn,sharing=locked \
    yarn install --frozen-lockfile --non-interactive --ignore-scripts
COPY . .
RUN yarn build

# --- Dépendances de production : uniquement celles du serveur ------------------------------------
FROM ${NODE_IMAGE} AS prod-deps
WORKDIR /app
COPY package.json yarn.lock ./
RUN --mount=type=cache,target=/usr/local/share/.cache/yarn,sharing=locked \
    yarn install --frozen-lockfile --non-interactive --production --ignore-scripts

# --- Runtime --------------------------------------------------------------------------------------
FROM ${ALPINE_IMAGE} AS runtime
# ffmpeg mesure le volume (EBU R128), convertit WAV→FLAC et encode la variante AAC.
# libstdc++ et libgcc sont les deux bibliothèques dynamiques du binaire Node.
# Les versions Alpine ne peuvent pas être figées durablement (hadolint DL3018).
# hadolint ignore=DL3018
RUN apk add --no-cache ffmpeg libstdc++ libgcc \
  && addgroup -g 101 player \
  && adduser -D -H -u 101 -G player player \
  && mkdir -p /data \
  && chown 101:101 /data
COPY --link --from=build /usr/local/bin/node /usr/local/bin/node
WORKDIR /app
ENV NODE_ENV=production PORT=8080 DATA_DIR=/data
# Fichiers appartenant à root, lus par l'utilisateur 101 : l'application est immuable.
COPY --link package.json /app/package.json
COPY --link --from=prod-deps /app/node_modules /app/node_modules
COPY --link --from=build /app/dist /app/dist
USER 101:101
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=70s --retries=3 \
  CMD ["wget", "-q", "-O", "/dev/null", "http://127.0.0.1:8080/healthz"]
CMD ["node", "--no-warnings=ExperimentalWarning", "dist/server/main.js"]
