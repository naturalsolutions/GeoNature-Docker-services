#!/bin/bash

set -a && source .env && set +a

: "${DOCKER_UID:=1000}"
: "${DOCKER_GID:=1000}"
: "${GEONATURE_DATA_DIR:=./data}"

if [ "$(basename "$GEONATURE_DATA_DIR")" = "geonature" ]; then
    DATA_ROOT="$(dirname "$GEONATURE_DATA_DIR")"
    GN_DATA_DIR="$GEONATURE_DATA_DIR"
else
    DATA_ROOT="$GEONATURE_DATA_DIR"
    GN_DATA_DIR="$GEONATURE_DATA_DIR/geonature"
fi
TRAEFIK_DATA_DIR="$DATA_ROOT/traefik"

if [ ! -d "$GEONATURE_CONFIG_DIR" ]; then
    mkdir -p "$GEONATURE_CONFIG_DIR"
fi

mkdir -p "$GN_DATA_DIR/custom"
mkdir -p "$GN_DATA_DIR/media"
mkdir -p "$TRAEFIK_DATA_DIR/certs"

if [ "$(id -u)" -eq 0 ]; then
    chown -R "${DOCKER_UID}:${DOCKER_GID}" "$DATA_ROOT"
    find "$DATA_ROOT" -type d -exec chmod 2775 {} +
    chmod -R g+rwX "$DATA_ROOT"
else
    echo "WARN: run as root to apply ownership and permissions on ${DATA_ROOT}"
fi

if [ ! -f "$GEONATURE_CONFIG_DIR/geonature/geonature_config.toml" ]; then
    mkdir -p "$GEONATURE_CONFIG_DIR/geonature"
    echo "SECRET_KEY = \"$(openssl rand -hex 16)\"" > "$GEONATURE_CONFIG_DIR/geonature/geonature_config.toml"
fi

if [ ! -f "$GEONATURE_CONFIG_DIR/usershub/config.py" ]; then
    mkdir -p "$GEONATURE_CONFIG_DIR/usershub"
    echo "SECRET_KEY = \"$(openssl rand -hex 16)\"" > "$GEONATURE_CONFIG_DIR/usershub/config.py"
fi

if [ ! -d "$GEONATURE_CONFIG_DIR/traefik" ]; then
    mkdir -p "$GEONATURE_CONFIG_DIR/traefik/certs"
fi

touch "$GEONATURE_CONFIG_DIR/geonature/dashboard_config.toml"
touch "$GEONATURE_CONFIG_DIR/geonature/exports_config.toml"
touch "$GEONATURE_CONFIG_DIR/geonature/monitorings_config.toml"
touch "$GEONATURE_CONFIG_DIR/geonature/import_config.toml"
